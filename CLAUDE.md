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
- No method wrapping or interception - just three straightforward class methods

**`Sidekiqable::AsyncProxy`** (lib/sidekiqable/async_proxy.rb)
- Simple proxy returned by `perform_async`, `perform_in`, and `perform_at`
- Uses `method_missing` to catch the actual method call (e.g., `.boo(1, 2)`)
- Validates arguments are Sidekiq-serializable via `Sidekiq.dump_json`
- Raises error if blocks are passed (cannot be serialized)
- Enqueues job to `Worker` with compact payload format: `["ClassName.method_name", *args]`
- Applies global configuration options (queue, retry) before enqueuing

**`Sidekiqable::Worker`** (lib/sidekiqable/worker.rb)
- Standard Sidekiq worker that executes scheduled method calls
- Receives compact payload: `["ClassName.method_name", *args]`
- Splits the callable string on first dot to extract class name and method name
- Constantizes class name and invokes method with args via `public_send`

**`Sidekiqable::Configuration`** (lib/sidekiqable/configuration.rb)
- Global configuration object accessed via `Sidekiqable.configuration`
- Supports `queue` and `retry` options applied to all jobs
- Returns hash of Sidekiq options for worker configuration

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

### Implementation Notes

- No method wrapping or hooks - just simple `method_missing` on proxy objects
- Compact payload format reduces serialization overhead
- Clear separation between sync and async code paths
- All complexity is isolated to the `AsyncProxy` class (~50 lines)

## Testing Notes

- Uses Minitest for testing
- Test helper location: test/test_helper.rb
- Current test coverage is minimal (placeholder test exists in test/test_sidekiqable.rb)

## Ruby Version

Requires Ruby >= 3.1.0 (specified in sidekiqable.gemspec)

## Dependencies

- sidekiq >= 6.0 (runtime dependency)
- minitest ~> 5.16 (development)
- rubocop ~> 1.21 (development)
