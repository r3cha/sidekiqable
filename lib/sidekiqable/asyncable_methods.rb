# frozen_string_literal: true

module Sidekiqable
  module AsyncableMethods
    def sidekiqable_options(options = nil)
      if options
        @sidekiqable_options = options
      else
        @sidekiqable_options ||= {}
      end
    end

    def perform_async
      Sidekiqable::AsyncProxy.new(self, :perform_async)
    end

    def perform_in(interval)
      Sidekiqable::AsyncProxy.new(self, :perform_in, interval)
    end

    def perform_at(timestamp)
      Sidekiqable::AsyncProxy.new(self, :perform_at, timestamp)
    end
  end
end
