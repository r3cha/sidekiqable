# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Sidekiqable is a Ruby gem that allows scheduling class methods asynchronously via Sidekiq without writing dedicated workers. It uses a simple proxy pattern where you prefix method calls with `perform_async`, `perform_in`, or `perform_at` (e.g., `Foo.perform_async.bar(1, 2)`).

## Development Commands

### Testing
```bash
rake test              # Run all tests
bundle exec minitest test/test_sidekiqable.rb  # Run specific test file
```

### Linting
```bash
rake rubocop           # Run RuboCop linter
rubocop -A             # Auto-correct offenses
```

### Build & Install
```bash
bundle exec rake install   # Install gem locally
bundle exec rake release   # Tag and release to RubyGems
```

### Interactive Console
```bash
bin/console            # Launch IRB with gem loaded
```

### Setup
```bash
bin/setup              # Install dependencies
```

## Architecture

### Core Components

**`Sidekiqable::AsyncableMethods`** (lib/sidekiqable/asyncable_methods.rb)
- Entry point module that classes extend to gain async capabilities
- Defines three simple methods: `perform_async`, `perform_in(interval)`, and `perform_at(timestamp)`
- Each method returns an `AsyncProxy` instance configured for the appropriate scheduling mode
- Provides `sidekiqable_options(options)` method for per-class configuration
- Options set per-class take precedence over global configuration
- No method wrapping or interception - just straightforward class methods

**`Sidekiqable::AsyncProxy`** (lib/sidekiqable/async_proxy.rb)
- Simple proxy returned by `perform_async`, `perform_in`, and `perform_at`
- Uses `method_missing` to catch the actual method call (e.g., `.boo(1, 2)`)
- Validates arguments are Sidekiq-serializable via `Sidekiq.dump_json` (can be disabled)
- Raises error if blocks are passed (cannot be serialized)
- Enqueues job to `Worker` with compact payload format: `["ClassName.method_name", *args]`
- Applies configuration options before enqueuing using Sidekiq's `.set()` API
- Configuration priority: per-class options > global options > Sidekiq defaults

**`Sidekiqable::Worker`** (lib/sidekiqable/worker.rb)
- Standard Sidekiq worker that executes scheduled method calls
- Receives compact payload: `["ClassName.method_name", *args]`
- Splits the callable string on first dot to extract class name and method name
- Constantizes class name and invokes method with args via `public_send`

**`Sidekiqable::Configuration`** (lib/sidekiqable/configuration.rb)
- Global configuration object accessed via `Sidekiqable.configuration`
- Supports all standard Sidekiq worker options: `queue`, `retry`, `dead`, `backtrace`, `pool`, `tags`
- Sidekiqable-specific option: `validate_arguments` (default: true)
- Returns hash of Sidekiq options for worker configuration via `sidekiq_options`
- Can be configured via `Sidekiqable.configure` or Rails' `config.sidekiqable`

**`Sidekiqable::Railtie`** (lib/sidekiqable/railtie.rb)
- Rails integration that exposes `config.sidekiqable` for environment-specific configuration
- Automatically loaded when Rails is detected

### Execution Flow

**Async Execution:**
1. User extends class with `Sidekiqable::AsyncableMethods`
2. User calls `Foo.perform_async` which returns an `AsyncProxy` instance
3. User chains method call like `.boo(1, 2)`
4. Proxy's `method_missing` catches the call
5. Proxy validates arguments and enqueues job to `Worker` with compact payload `["Foo.boo", 1, 2]`
6. Worker splits "Foo.boo", constantizes `Foo`, and invokes `boo(1, 2)`

**Sync Execution:**
1. User calls method normally: `Foo.boo(1, 2)`
2. Method executes immediately (no proxy involved)
3. Returns result directly

### Configuration System

**Three levels of configuration (in order of precedence):**

1. **Per-class options** (highest priority) - Set via `sidekiqable_options` in the class
   ```ruby
   class Foo
     extend Sidekiqable::AsyncableMethods
     sidekiqable_options queue: 'high', retry: 3
   end
   ```

2. **Global configuration** - Set via `Sidekiqable.configure` or Rails `config.sidekiqable`
   ```ruby
   Sidekiqable.configure do |config|
     config.queue = 'default'
     config.retry = 5
     config.validate_arguments = true
   end
   ```

3. **Sidekiq defaults** (lowest priority) - Used when not configured

**Available options:**
- Standard Sidekiq options: `queue`, `retry`, `dead`, `backtrace`, `pool`, `tags`
- Sidekiqable-specific: `validate_arguments` (enables/disables argument serialization validation)

**How options are applied:**
- `AsyncProxy` merges per-class and global options
- Uses Sidekiq's `.set()` API to apply options: `Worker.set(options).perform_async(...)`
- This happens at enqueue time, not worker definition time

### Implementation Notes

- No method wrapping or hooks - just simple `method_missing` on proxy objects
- Compact payload format reduces serialization overhead
- Clear separation between sync and async code paths
- All complexity is isolated to the `AsyncProxy` class (~50 lines)
- Configuration is applied dynamically at enqueue time, not on the Worker class itself

## Testing Notes

- Uses Minitest for testing with Sidekiq test mode
- Test helper location: test/test_helper.rb
- Tests cover: version check, method presence, async enqueuing, delayed jobs, worker execution, block rejection, and sync calls
- Run with `rake test` or `bundle exec rake test`

## Key Design Decisions

### Why the current API: `Foo.perform_async.bar(1, 2)`?

This syntax was chosen for clarity and simplicity:
- **Clear intent**: Starting with `perform_async` makes async behavior explicit
- **No method wrapping**: Avoids complex metaprogramming with `singleton_method_added` hooks
- **Familiar**: Similar to Sidekiq's standard `Worker.perform_async` pattern
- **Simple implementation**: Just 3 methods + proxy with `method_missing` (~60 total lines)

Alternative syntaxes considered:
- `Foo.bar(1, 2).perform_async` - Requires wrapping ALL methods, adds overhead
- `Foo.async.bar(1, 2)` - Similar to current, but less Sidekiq-like
- `Foo.bar_async(1, 2)` - Requires suffix convention, less flexible

### Why compact payload format: `["Foo.bar", 1, 2]`?

- **Reduces serialization size**: One less array element per job
- **Cleaner Sidekiq UI**: Job args look more natural
- **No edge cases**: Method names can't contain dots in Ruby, so parsing is safe

Alternative considered:
- `["Foo", "bar", 1, 2]` - More structured but slightly larger payload

### Why dynamic configuration via `.set()`?

Configuration is applied at enqueue time using `Worker.set(options)` rather than defining `sidekiq_options` on the Worker class:
- **Flexibility**: Per-class options can override global config
- **Single worker**: One `Worker` class handles all jobs, options vary per caller
- **Standard Sidekiq pattern**: Uses `.set()` API that all Sidekiq users know

## Ruby Version

Requires Ruby >= 3.1.0 (specified in sidekiqable.gemspec)

## Dependencies

- sidekiq >= 6.0 (runtime dependency)
- minitest ~> 5.16 (development)
- rubocop ~> 1.21 (development)
