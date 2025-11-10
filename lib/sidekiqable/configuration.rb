# frozen_string_literal: true

module Sidekiqable
  class Configuration
    attr_accessor :queue, :retry, :dead, :backtrace, :pool, :tags, :validate_arguments

    def initialize
      @queue = "default"
      @retry = true
      @dead = true
      @backtrace = false
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
  end
end
