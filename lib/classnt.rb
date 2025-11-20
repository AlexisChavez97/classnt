# frozen_string_literal: true

require_relative "classnt/version"
require_relative "classnt/result"
require_relative "classnt/dsl"

# Main module for Classnt library providing pipeline and transaction utilities.
module Classnt
  class Error < StandardError; end

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
    def pipe(input, *steps)
      steps.reduce(Classnt.ok(input)) do |result, step|
        result.then do |value|
          # If step is a symbol, try to call it as a method on the host module/class
          if step.is_a?(Symbol)
            send(step, value)
          else
            # Assume it's a callable (proc/lambda/method object)
            step.call(value)
          end
        end
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
      yield
    end
  rescue Rollback => e
    e.result
  end
end
