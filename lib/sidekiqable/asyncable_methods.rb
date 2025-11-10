module Sidekiqable
  module AsyncableMethods
    RESERVED_METHOD_PREFIX = "__asyncable__"
    RESERVED_METHODS = %i[
      method_missing
      respond_to_missing?
    ].freeze

    class << self
      def extended(base)
        install_hooks!(base)
        wrap_existing_singleton_methods!(base)
      end

      def reserved_method?(method_name)
        RESERVED_METHODS.include?(method_name) ||
          method_name.to_s.start_with?(RESERVED_METHOD_PREFIX)
      end

      def install_hooks!(base)
        eigenclass = base.singleton_class
        return if eigenclass < SingletonExtensions

        eigenclass.prepend(SingletonExtensions)
      end

      def wrap_existing_singleton_methods!(base)
        base.singleton_methods(false).each do |method_name|
          wrap_singleton_method!(base, method_name)
        end
      end

      def wrap_singleton_method!(base, method_name)
        return if reserved_method?(method_name)

        eigenclass = base.singleton_class
        wrapping_flag = :@__asyncable_wrapping

        return if eigenclass.instance_variable_get(wrapping_flag)

        unless eigenclass.instance_methods(false).include?(method_name)
          # Method might be defined via method_missing; skip wrapping
          return
        end

        original_implementation = eigenclass.instance_method(method_name)

        eigenclass.instance_variable_set(wrapping_flag, true)
        eigenclass.define_method(method_name) do |*args, &block|
          executor = lambda do
            original_implementation.bind(self).call(*args, &block)
          end

          Sidekiqable::MethodInvocationProxy.new(self, method_name, args, block, executor)
        end
      ensure
        eigenclass.instance_variable_set(wrapping_flag, false)
      rescue NameError
        # Skip methods that cannot be captured as unbound (e.g. built-ins)
      end
    end

    module SingletonExtensions
      def singleton_method_added(method_name)
        super if defined?(super)
        AsyncableMethods.wrap_singleton_method!(self, method_name)
      end

      def method_missing(method_name, *args, &block)
        return super if AsyncableMethods.reserved_method?(method_name)

        executor = lambda do
          super(method_name, *args, &block)
        end

        Sidekiqable::MethodInvocationProxy.new(self, method_name, args, block, executor)
      end

      def respond_to_missing?(method_name, include_private = false)
        return false if AsyncableMethods.reserved_method?(method_name)

        super
      end
    end
  end
end


