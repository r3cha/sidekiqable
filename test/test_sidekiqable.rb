# frozen_string_literal: true

require "test_helper"
require "sidekiq/testing"

class TestSidekiqable < Minitest::Test
  def setup
    Sidekiq::Testing.fake!
    Sidekiq::Worker.clear_all
  end

  def test_that_it_has_a_version_number
    refute_nil ::Sidekiqable::VERSION
  end

  def test_extend_adds_perform_methods
    klass = Class.new do
      extend Sidekiqable::AsyncableMethods
    end

    assert_respond_to klass, :perform_async
    assert_respond_to klass, :perform_in
    assert_respond_to klass, :perform_at
  end

  def test_perform_async_enqueues_job
    test_class = Class.new do
      extend Sidekiqable::AsyncableMethods

      def self.test_method(arg1, arg2)
        arg1 + arg2
      end
    end
    stub_const("TestClass", test_class)

    test_class.perform_async.test_method(1, 2)

    assert_equal 1, Sidekiqable::Worker.jobs.size
    job = Sidekiqable::Worker.jobs.first
    assert_equal ["TestClass.test_method", 1, 2], job["args"]
  end

  def test_perform_in_enqueues_job_with_delay
    test_class = Class.new do
      extend Sidekiqable::AsyncableMethods

      def self.test_method(arg)
        arg
      end
    end
    stub_const("TestClass", test_class)

    test_class.perform_in(300).test_method("hello")

    assert_equal 1, Sidekiqable::Worker.jobs.size
    job = Sidekiqable::Worker.jobs.first
    assert_equal ["TestClass.test_method", "hello"], job["args"]
    assert job["at"]
  end

  def test_perform_at_enqueues_job_with_timestamp
    test_class = Class.new do
      extend Sidekiqable::AsyncableMethods

      def self.test_method
        "executed"
      end
    end
    stub_const("TestClass", test_class)

    timestamp = Time.now.to_i + 3600
    test_class.perform_at(timestamp).test_method

    assert_equal 1, Sidekiqable::Worker.jobs.size
    job = Sidekiqable::Worker.jobs.first
    assert_equal ["TestClass.test_method"], job["args"]
    assert job["at"]
  end

  def test_worker_executes_method
    test_class = Class.new do
      extend Sidekiqable::AsyncableMethods

      def self.test_method(a, b)
        a * b
      end
    end

    # Keep the constant alive during worker execution
    Object.const_set("TestClass", test_class)

    worker = Sidekiqable::Worker.new
    result = worker.perform("TestClass.test_method", 3, 4)

    assert_equal 12, result
  ensure
    Object.send(:remove_const, "TestClass") if Object.const_defined?("TestClass")
  end

  def test_raises_error_on_block
    test_class = Class.new do
      extend Sidekiqable::AsyncableMethods

      def self.test_method(&block)
        block.call
      end
    end
    stub_const("TestClass", test_class)

    error = assert_raises(Sidekiqable::Error) do
      test_class.perform_async.test_method { "block" }
    end

    assert_match(/Cannot enqueue blocks/, error.message)
  end

  def test_synchronous_calls_still_work
    test_class = Class.new do
      extend Sidekiqable::AsyncableMethods

      def self.test_method(x)
        x * 2
      end
    end
    stub_const("TestClass", test_class)

    result = test_class.test_method(5)
    assert_equal 10, result
  end

  private

  def stub_const(name, value)
    Object.const_set(name, value)
  ensure
    # Clean up after test
    Object.send(:remove_const, name) if Object.const_defined?(name)
  end
end
