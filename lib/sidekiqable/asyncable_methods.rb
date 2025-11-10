# frozen_string_literal: true

module Sidekiqable
  module AsyncableMethods
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
