# frozen_string_literal: true

module Classnt
  # Represents the result of an operation, either :ok or :error/:failure.
  class Result
    attr_reader :type, :value

    def initialize(type, value)
      @type = type
      @value = value
    end

    def ok?
      @type == :ok
    end

    def value!
      return @value if ok?

      raise Classnt::UnwrapError, @value
    end

    def failure?
      @type == :error || @type == :failure
    end

    # The pipe operator.
    # If the current result is ok, it yields the value to the block/proc.
    # The block/proc is expected to return a Tuple [:ok, val] or [:error, err]
    # OR a Result object.
    def pipe(callable = nil, &block)
      return self if failure?

      callable ||= block
      result = callable.call(@value)
      Classnt.wrap(result)
    end

    alias then pipe
    alias then_pipe pipe

    def map
      return self if failure?

      Classnt.ok(yield(@value))
    end

    def on_success
      yield(@value) if ok?
      self
    end

    alias tap_ok on_success

    def on_failure
      yield(@value) if failure?
      self
    end

    def match
      matcher = Matcher.new
      yield matcher

      if ok?
        matcher.call_success(@value)
      else
        matcher.call_failure(@value)
      end
    end

    def unwrap
      [@type, @value]
    end

    def deconstruct
      [@type, @value]
    end

    def deconstruct_keys(_keys)
      { type: @type, value: @value }
    end
  end

  # Helper class for pattern matching on Result objects.
  class Matcher
    def initialize
      @success_handler = ->(v) { v }
      @failure_handler = ->(e) { e }
    end

    def success(&block)
      @success_handler = block
    end

    def failure(&block)
      @failure_handler = block
    end

    def call_success(value)
      @success_handler.call(value)
    end

    def call_failure(error)
      @failure_handler.call(error)
    end
  end
end
