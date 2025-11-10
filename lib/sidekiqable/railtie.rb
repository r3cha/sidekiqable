# frozen_string_literal: true

require "active_support/ordered_options"
require "rails/railtie"

module Sidekiqable
  class Railtie < ::Rails::Railtie
    config.sidekiqable = ActiveSupport::OrderedOptions.new

    initializer "sidekiqable.configure" do |app|
      options = app.config.sidekiqable

      Sidekiqable.configure do |config|
        config.queue = options.queue if options.key?(:queue)
        config.retry = options.retry if options.key?(:retry)
      end
    end
  end
end
