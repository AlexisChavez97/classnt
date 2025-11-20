# frozen_string_literal: true

module Classnt
  # DSL for defining pipelines declaratively.
  module DSL
    def self.extended(base)
      # When extended, `base` is the class or module (CoffeeMachine or CoffeeService).
      # We want `base` to have `pipe` available as a class method AND instance method?

      # If base is a module, we extend it with Pipeline so it has class-level `pipe`.
      base.extend(Classnt::Pipeline)
      
      # If base is a Class, we want instances to have `pipe`.
      # `base.include(Classnt::Pipeline)` would give instances access to `pipe`.
      base.include(Classnt::Pipeline) if base.is_a?(Class)

      # If extended into a Module (not a Class), make it behave like a service object
      # where instance methods become class methods (like `extend self`).
      base.extend(base) if base.instance_of?(Module)
    end

    # Defines a pipeline method on the host module/class.
    #
    # @param name [Symbol] The name of the method to generate.
    # @param transaction [Boolean] Whether to wrap the pipeline in a transaction.
    # @param block [Proc] The block defining the steps.
    def pipeline(name, transaction: false, &)
      builder = Builder.new
      builder.instance_eval(&)
      steps = builder.steps

      define_method(name) do |input|
        run_pipeline = lambda {
          # We use the `pipe` method.
          # If `self` is a module (service object), it has `pipe` via `extend Classnt::Pipeline`.
          # If `self` is an instance (class usage), it needs `include Classnt::Pipeline`.
          pipe(input, *steps)
        }

        if transaction
          Classnt.transaction(&run_pipeline)
        else
          run_pipeline.call
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
        @steps << name
      end
    end
  end
end
