module Sidekiqable
  class GenericMethodWorker
    include Sidekiq::Worker

    def perform(class_name, method_name, *args)
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


