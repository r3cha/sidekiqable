# Sidekiqable

Sidekiqable lets you enqueue any class method or modules asynchronously without writing dedicated Sidekiq workers or ActiveJob wrappers. Chain `perform_async`, `perform_in`, or `perform_at` directly off a class method invocation and Sidekiqable will serialize the call into a generic worker.

```ruby
class ReportMailer
  extend Sidekiqable::AsyncableMethods

  def self.deliver_daily(user_id)
    UserMailer.daily_report(user_id).deliver_now
  end
end

ReportMailer.deliver_daily(42).perform_async
ReportMailer.deliver_daily(42).perform_in(5.minutes)
```

The scheduled job will execute `ReportMailer.deliver_daily(42)` later via `Sidekiqable::GenericMethodWorker`.

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
2. Call the method normally and then chain the desired Sidekiq scheduling helper.

```ruby
class Foo
  extend Sidekiqable::AsyncableMethods

  def self.boo(a, b)
    Rails.logger.info("boo(#{a}, #{b})")
  end
end

# Immediately enqueue
Foo.boo(1, 2).perform_async

# Schedule relative to now
Foo.boo(1, 2).perform_in(5.minutes)

# Schedule at a specific time
Foo.boo(1, 2).perform_at(1.day.from_now)
```

Jobs are enqueued with the payload `["Foo", "boo", 1, 2]` and executed by `Sidekiqable::GenericMethodWorker`, which constantizes the class and invokes the method.

### Synchronous execution

If you call any other method on the proxy (or explicitly call `#call`, `#result`, or `#value`) the underlying method executes immediately and the return value is proxied back.

```ruby
Foo.boo(1, 2).call # => executes synchronously and returns the original value
```

### Configuration

Use the global configuration to set default Sidekiq options such as queue name or retry behaviour:

```ruby
Sidekiqable.configure do |config|
  config.queue = "mailers"
  config.retry = 5
end
```

Inside Rails you can configure via `config.sidekiqable`:

```ruby
# config/application.rb or an environment file
config.sidekiqable.queue = "low"
config.sidekiqable.retry = false
```

These values are applied to every job dispatched through `Sidekiqable::GenericMethodWorker` (and can still be overridden per job with Sidekiq’s standard `set` API if needed).

### Argument safety

Arguments are validated with `Sidekiq.dump_json` before enqueuing to ensure they can be serialized by Sidekiq. Passing a block while enqueuing will raise an error because Sidekiq cannot persist blocks.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to execute the test suite. You can also run `bin/console` to experiment with the gem.

To install the gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `lib/sidekiqable/version.rb` and then run `bundle exec rake release`. This tags the release and pushes the `.gem` to RubyGems (once your credentials are configured).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/r3cha/sidekiqable. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/r3cha/sidekiqable/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
