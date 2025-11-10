# frozen_string_literal: true

module Sidekiqable
  class Worker
    include Sidekiq::Worker

    def perform(callable, *args)
      class_name, method_name = callable.split(".", 2)
      klass = constantize!(class_name)
      klass.public_send(method_name, *args)
    end

    private

    def constantize!(name)
      Object.const_get(name)
    rescue NameError => e
      raise Sidekiqable::Error, "Failed to constantize #{name}: #{e.message}"
    end
  end
end
