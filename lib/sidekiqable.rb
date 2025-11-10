# frozen_string_literal: true

require "sidekiq"

require_relative "sidekiqable/version"
require_relative "sidekiqable/configuration"
require_relative "sidekiqable/generic_method_worker"
require_relative "sidekiqable/method_invocation_proxy"
require_relative "sidekiqable/asyncable_methods"
require_relative "sidekiqable/railtie" if defined?(Rails::Railtie)

module Sidekiqable
  class Error < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end
  end
end

