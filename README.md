# Sidekiqable

Sidekiqable lets you enqueue any class method or modules function asynchronously without writing dedicated Sidekiq workers or ActiveJob wrappers. Prefix method calls with `perform_async`, `perform_in`, or `perform_at` and Sidekiqable will serialize the call into a generic worker.

```ruby
class ReportMailer
  extend Sidekiqable::AsyncableMethods

  def self.deliver_daily(user_id)
    # ...
  end
end

ReportMailer.perform_async.deliver_daily(42)
ReportMailer.perform_in(5.minutes).deliver_daily(42)
```

The scheduled job will execute `ReportMailer.deliver_daily(42)` later via `Sidekiqable::Worker`.

## Installation

Add the gem to your application:

```bash
bundle add sidekiqable
```

Or install it manually:

```bash
gem install sidekiqable
```

### Rails

When used in a Rails application the included Railtie automatically loads Sidekiqable and exposes `config.sidekiqable` for environment-specific defaults.

## Usage

1. Add `Sidekiqable::AsyncableMethods` to any class whose class methods you want to schedule.
2. Prefix method calls with the desired Sidekiq scheduling helper (`perform_async`, `perform_in`, or `perform_at`).

```ruby
class Foo
  extend Sidekiqable::AsyncableMethods

  def self.boo(a, b)
    Rails.logger.info("boo(#{a}, #{b})")
  end
end

# Immediately enqueue
Foo.perform_async.boo(1, 2)

# Schedule relative to now
Foo.perform_in(5.minutes).boo(1, 2)

# Schedule at a specific time
Foo.perform_at(1.day.from_now).boo(1, 2)
```

Jobs are enqueued with the payload `["Foo.boo", 1, 2]` and executed by `Sidekiqable::Worker`, which constantizes the class and invokes the method.

### Synchronous execution

Normal method calls execute immediately without any async behavior.

```ruby
Foo.boo(1, 2) # => executes synchronously and returns the original value
```

### Configuration

#### Global Configuration

Use the global configuration to set default Sidekiq options for all classes. If not configured, Sidekiqable uses Sidekiq's default values:

```ruby
Sidekiqable.configure do |config|
  config.queue = "mailers"       # default: "default"
  config.retry = 5               # default: true
  config.dead = true             # default: true
  config.backtrace = 10          # default: false (or integer for lines)
  config.tags = ["reporting"]    # default: nil
  config.validate_arguments = true  # default: true (Sidekiqable-specific)
end
```

Inside Rails you can configure via `config.sidekiqable`:

```ruby
# config/application.rb or an environment file
config.sidekiqable.queue = "low"
config.sidekiqable.retry = false
config.sidekiqable.dead = false
config.sidekiqable.backtrace = false
config.sidekiqable.tags = ["background"]
config.sidekiqable.validate_arguments = false  # disable validation for performance
```

#### Per-Class Configuration

You can override global options for specific classes using `sidekiqable_options`:

```ruby
class ReportMailer
  extend Sidekiqable::AsyncableMethods
  
  sidekiqable_options queue: 'high_priority', 
                      retry: 3,
                      backtrace: 20,
                      tags: ['mailer', 'critical']
  
  def self.deliver_daily(user_id)
    # ...
  end
end

class BackgroundTask
  extend Sidekiqable::AsyncableMethods
  
  sidekiqable_options queue: 'low_priority', 
                      retry: false,
                      dead: false
  
  def self.cleanup
    # ...
  end
end
```

Per-class options take precedence over global configuration. Any Sidekiq option supported by `worker.set()` can be used.

#### Available options

**Sidekiq job options** (uses Sidekiq defaults when not configured):

- `queue`: Use a named queue for jobs
  - **Default:** `"default"`
- `retry`: Enable retries for jobs. Can be `true`, `false`, or an integer for max retry attempts
  - **Default:** `true`
  - **Example:** `retry: 3` (retry up to 3 times)
- `dead`: Whether a failing job should go to the Dead queue after exhausting retries
  - **Default:** `true`
- `backtrace`: Whether to save error backtrace in the retry payload for the Web UI. Can be `true`, `false`, or an integer for number of lines to save
  - **Default:** `false`
  - **Warning:** Backtraces are large and can consume significant Redis space with many retries. Consider using an error service like Honeybadger instead.
- `pool`: Use the given Redis connection pool to push this job type to a specific shard
  - **Default:** `nil` (uses default Sidekiq connection)
- `tags`: Add an Array of tags to each job for filtering in the Web UI
  - **Default:** `nil`
  - **Example:** `tags: ["reporting", "daily"]`

**Sidekiqable-specific options:**

- `validate_arguments`: Enable/disable argument serialization validation before enqueuing. When enabled, provides clear error messages for non-serializable arguments. Disable for better performance if you're confident your arguments are always serializable.
  - **Default:** `true`

### Argument safety

By default, arguments are validated with `Sidekiq.dump_json` before enqueuing to ensure they can be serialized by Sidekiq. This validation can be disabled via `config.validate_arguments = false` if needed. Passing a block while enqueuing will always raise an error because Sidekiq cannot persist blocks.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to execute the test suite. You can also run `bin/console` to experiment with the gem.

To install the gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `lib/sidekiqable/version.rb` and then run `bundle exec rake release`. This tags the release and pushes the `.gem` to RubyGems (once your credentials are configured).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/r3cha/sidekiqable. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/r3cha/sidekiqable/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
