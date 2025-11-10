# frozen_string_literal: true

module Sidekiqable
  class Configuration
    attr_accessor :queue, :retry, :dead, :backtrace, :pool, :tags, :validate_arguments

    def initialize
      @queue = sidekiq_default("queue")
      @retry = sidekiq_default("retry")
      @dead = sidekiq_default("dead")
      @backtrace = sidekiq_default("backtrace")
      @pool = nil
      @tags = nil
      @validate_arguments = true
    end

    def sidekiq_options
      {}.tap do |opts|
        opts[:queue] = queue if queue
        opts[:retry] = @retry unless @retry.nil?
        opts[:dead] = dead unless dead.nil?
        opts[:backtrace] = backtrace unless backtrace.nil?
        opts[:pool] = pool if pool
        opts[:tags] = tags if tags
      end
    end

    private

    def sidekiq_default(option)
      Sidekiq::Worker::ClassMethods::DEFAULT_OPTIONS[option]
    rescue NameError
      # Fallback to Sidekiq's documented defaults if DEFAULT_OPTIONS is not available
      case option
      when "retry" then true
      when "queue" then "default"
      when "dead" then true
      when "backtrace" then false
      end
    end
  end
end
