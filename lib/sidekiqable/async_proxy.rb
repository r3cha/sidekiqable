# frozen_string_literal: true

module Sidekiqable
  class AsyncProxy
    def initialize(target_class, mode, schedule_arg = nil)
      @target_class = target_class
      @mode = mode
      @schedule_arg = schedule_arg
    end

    def method_missing(method_name, *args, &block)
      raise Sidekiqable::Error, "Cannot enqueue blocks to Sidekiq" if block

      validate_serializable!(method_name, args)

      worker_class = Sidekiqable::Worker
      worker = apply_config(worker_class)

      # Compact payload: "ClassName.method_name" instead of separate args
      callable = "#{@target_class.name}.#{method_name}"
      payload = [callable, *args]

      case @mode
      when :perform_async
        worker.perform_async(*payload)
      when :perform_in
        worker.perform_in(@schedule_arg, *payload)
      when :perform_at
        worker.perform_at(@schedule_arg, *payload)
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @target_class.respond_to?(method_name, include_private)
    end

    private

    def validate_serializable!(method_name, args)
      callable = "#{@target_class.name}.#{method_name}"
      Sidekiq.dump_json([callable, *args])
    rescue Sidekiq::Error, JSON::GeneratorError => e
      raise Sidekiqable::Error,
            "Arguments for #{@target_class}##{method_name} are not Sidekiq-serializable: #{e.message}"
    end

    def apply_config(worker_class)
      options = Sidekiqable.configuration.sidekiq_options
      options.empty? ? worker_class : worker_class.set(options)
    end
  end
end
