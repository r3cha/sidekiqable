require "json"

module Sidekiqable
  class MethodInvocationProxy
    ASYNC_METHODS = %i[
      perform_async
      perform_in
      perform_at
      call
      value
      result
      sync
    ].freeze

    attr_reader :target_class, :method_name, :arguments

    def initialize(target_class, method_name, arguments, block, executor)
      @target_class = target_class
      @method_name = method_name
      @arguments = arguments
      @block = block
      @executor = executor
      @performed = false
      @result = nil
    end

    def perform_async
      enqueue(:perform_async)
    end

    def perform_in(interval)
      enqueue(:perform_in, interval)
    end

    def perform_at(timestamp)
      enqueue(:perform_at, timestamp)
    end

    def call
      execute
    end
    alias sync call
    alias value call
    alias result call

    def performed?
      @performed
    end

    def method_missing(name, *args, &block)
      return super unless executed_result.respond_to?(name)

      executed_result.public_send(name, *args, &block)
    end

    def respond_to_missing?(name, include_private = false)
      return true if ASYNC_METHODS.include?(name)
      return @result.respond_to?(name, include_private) if @performed

      super
    end

    def to_s
      "#<#{self.class}:0x#{object_id.to_s(16)} #{target_class}##{method_name}(#{arguments.map(&:inspect).join(', ')})>"
    end

    private

    def enqueue(mode, schedule_arg = nil)
      ensure_async_safe!

      worker_class = Sidekiqable::GenericMethodWorker
      options = Sidekiqable.configuration.sidekiq_options
      worker_client = options.empty? ? worker_class : worker_class.set(options)

      payload = [serialized_class_name, serialized_method_name, *arguments]

      case mode
      when :perform_async
        worker_client.perform_async(*payload)
      when :perform_in
        worker_client.perform_in(schedule_arg, *payload)
      when :perform_at
        worker_client.perform_at(schedule_arg, *payload)
      else
        raise ArgumentError, "Unsupported mode #{mode.inspect}"
      end
    end

    def ensure_async_safe!
      raise Sidekiqable::Error, "Blocks cannot be enqueued to Sidekiq" if @block

      Sidekiq.dump_json(arguments_payload_for_validation)
      true
    rescue Sidekiq::Error, Sidekiq::ArgumentError, JSON::GeneratorError => e
      raise Sidekiqable::Error, "Arguments for #{target_class}##{method_name} are not Sidekiq-serializable: #{e.message}"
    end

    def arguments_payload_for_validation
      [serialized_class_name, serialized_method_name, *arguments]
    end

    def serialized_class_name
      target_class.name || raise(Sidekiqable::Error, "Anonymous classes are not supported for async execution")
    end

    def serialized_method_name
      method_name.to_s
    end

    def execute
      @performed = true
      @result ||= @executor.call
    end

    def executed_result
      execute
    end
  end
end


