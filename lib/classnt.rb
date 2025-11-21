# frozen_string_literal: true

require_relative "classnt/version"
require_relative "classnt/result"

# Main module for Classnt library providing pipeline and transaction utilities.
module Classnt
  class Error < StandardError; end

  # Exception raised when unwrapping a failure result with value!.
  class UnwrapError < Error
    attr_reader :result_value

    def initialize(value)
      @result_value = value
      super("Unwrapped failure result: #{value.inspect}")
    end
  end

  # Exception raised to trigger a rollback in transactions when a Result is a failure.
  class Rollback < StandardError
    attr_reader :result

    def initialize(result)
      @result = result
      super("Rollback triggered by failure result")
    end
  end

  # Mixin for declarative pipeline usage
  module Pipeline
    Step = Struct.new(:name, :map, :callable)

    def self.extended(base)
      # If extended into a Module (not a Class), make it behave like a service object
      # where instance methods become class methods (like `extend self`).
      base.extend(base) if base.instance_of?(Module)
    end

    def pipe(input, *steps)
      # Normalize steps to Step struct
      steps = steps.map do |s|
        case s
        when Step then s
        when Symbol then Step.new(s, false, nil)
        when Hash then Step.new(s[:name], s[:map], nil)
        else Step.new(nil, false, s) # Callable
        end
      end

      steps.reduce(Classnt.ok(input)) do |result, step|
        result.then do |value|
          output = if step.name
                     send(step.name, value)
                   else
                     step.callable.call(value)
                   end

          step.map ? Classnt.ok(output) : output
        end
      end
    end

    # Defines a pipeline method on the host module/class.
    #
    # @param name [Symbol] The name of the method to generate.
    # @param transaction [Boolean] Whether to wrap the pipeline in a transaction.
    # @param safe [Boolean] Whether to rescue StandardError and return a failure result.
    # @param block [Proc] The block defining the steps.
    def pipeline(name, transaction: false, safe: false, &)
      builder = Builder.new
      builder.instance_eval(&)
      steps = builder.steps

      # Update: Accept a block (&block)
      define_method(name) do |input, &block|
        run_pipeline = lambda {
          # We use the `pipe` method.
          # If `self` is a module (service object), it has `pipe` via `extend Classnt::Pipeline`.
          # If `self` is an instance (class usage), it needs `include Classnt::Pipeline`.
          begin
            pipe(input, *steps)
          rescue StandardError => e
            raise e unless safe

            Classnt.error(e.message)
          end
        }

        # Update: Capture the result first
        result = if transaction
                   Classnt.transaction(&run_pipeline)
                 else
                   run_pipeline.call
                 end

        # Update: If a block was passed, treat it as a match block
        if block
          result.match(&block)
        else
          result
        end
      end

      # If we are in a module (but not a class), make it a module_function
      module_function(name) if is_a?(Module) && !is_a?(Class)
    end

    class Builder
      attr_reader :steps

      def initialize
        @steps = []
      end

      def step(name)
        @steps << Step.new(name, false, nil)
      end

      def map(name)
        @steps << Step.new(name, true, nil)
      end
    end
  end

  module_function

  def ok(value)
    Result.new(:ok, value)
  end

  def error(value)
    Result.new(:error, value)
  end

  # Alias for starting a pipeline
  def pipe(value)
    ok(value)
  end

  # Wraps a raw tuple [:ok, val] or [:error, err] into a Result object.
  # If it's already a Result, return it.
  def wrap(object)
    return object if object.is_a?(Result)

    return Result.new(object[0], object[1]) if object.is_a?(Array) && %i[ok error failure].include?(object[0])

    # Fallback: treat unknown returns as success? Or raise?
    # For now, let's assume everything else is a successful value return if it's not a tuple.
    # But the design says "functions returning [:ok, value]".
    # So strictly we might want to enforce tuples.
    # For friendliness, let's raise if it's not a recognized shape to help debugging.
    raise Error, "Invalid return value in pipeline: #{object.inspect}. Expected [:ok, val], [:error, err] or Classnt::Result"
  end

  # Experimental transaction wrapper
  def transaction
    if defined?(ActiveRecord::Base)
      ActiveRecord::Base.transaction do
        result = yield
        # If the block returns a Result object that is a failure, we might want to rollback.
        # However, usually transactions rollback on exception.
        # If we want to support "rollback on failure result", we need to raise specific exception.

        if result.is_a?(Result) && result.failure?
          raise Rollback, result
        elsif result.is_a?(Array) && %i[error failure].include?(result[0])
          # It's a tuple failure
          raise Rollback, wrap(result)
        end

        result
      end
    else
      # No ActiveRecord, just yield
      warn "WARNING: Transaction requested but ActiveRecord not defined. Running without transaction."
      yield
    end
  rescue Rollback => e
    e.result
  end
end
