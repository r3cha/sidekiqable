module Sidekiqable
  class Configuration
    attr_accessor :queue
    attr_writer :retry

    def initialize
      @queue = nil
      @retry = nil
    end

    def retry
      return @retry unless @retry.nil?

      Sidekiq::Worker::ClassMethods::DEFAULT_OPTIONS["retry"]
    rescue NameError
      true
    end

    def sidekiq_options
      {}.tap do |opts|
        opts[:queue] = queue if queue
        opts[:retry] = @retry unless @retry.nil?
      end
    end
  end
end


