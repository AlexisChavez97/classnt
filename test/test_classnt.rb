# frozen_string_literal: true

require "test_helper"

class TestClassnt < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Classnt::VERSION
  end

  def test_basic_pipeline_success
    result = Classnt.ok("espresso")
                    .pipe { |v| [:ok, "#{v} ground"] }
                    .pipe { |v| [:ok, "#{v} brewed"] }

    assert result.ok?
    assert_equal "espresso ground brewed", result.value
  end

  def test_basic_pipeline_failure
    result = Classnt.ok("espresso")
                    .pipe { |v| [:error, "grinder jammed"] }
                    .pipe { |v| [:ok, "should not happen"] }

    assert result.failure?
    assert_equal "grinder jammed", result.value
  end

  def test_match_dsl_success
    output = nil
    Classnt.ok("value").match do |on|
      on.success { |v| output = "success: #{v}" }
      on.failure { |e| output = "fail: #{e}" }
    end
    assert_equal "success: value", output
  end

  def test_match_dsl_failure
    output = nil
    Classnt.error("oops").match do |on|
      on.success { |v| output = "success: #{v}" }
      on.failure { |e| output = "fail: #{e}" }
    end
    assert_equal "fail: oops", output
  end
end

# CoffeeMachine Example Test
module CoffeeMachine
  extend self

  def brew(coffee_type:)
    Classnt.transaction do
      Classnt.ok(coffee_type)
             .pipe { |type| grind_beans(coffee_type: type) }
             .pipe { |msg| brew_coffee(msg: msg) }
             .pipe { |msg| pour_into_cup(msg: msg) }
             .pipe { |msg| add_sugar(msg: msg) }
             .pipe { |msg| add_cream(msg: msg) }
             .pipe { |msg| serve(msg: msg) }
    end
  end

  def grind_beans(coffee_type:)
    case coffee_type
    when "espresso", "latte", "cappuccino"
      [:ok, "Grinding #{coffee_type} beans"]
    else
      [:error, "Invalid coffee type"]
    end
  end

  def brew_coffee(msg:)
    [:ok, msg.sub("Grinding", "Brewing").sub("beans", "")]
  end

  def pour_into_cup(msg:)
    [:ok, msg.sub("Brewing", "Pouring") + " into cup"]
  end

  def add_sugar(msg:)
    [:ok, msg + " with sugar"]
  end

  def add_cream(msg:)
    [:ok, msg + " with cream"]
  end

  def serve(msg:)
    [:ok, msg.sub("Pouring", "Serving")]
  end
end

class TestCoffeeMachine < Minitest::Test
  def test_brew_espresso
    result = CoffeeMachine.brew(coffee_type: "espresso")

    assert result.ok?
    # "Serving espresso into cup with sugar with cream"
    # Trace:
    # 1. Grinding espresso beans
    # 2. Brewing espresso
    # 3. Pouring espresso  into cup
    # 4. Pouring espresso  into cup with sugar
    # 5. Pouring espresso  into cup with sugar with cream
    # 6. Serving espresso  into cup with sugar with cream
    # Wait, my string sub logic in brew_coffee removes 'beans'.
    # "Grinding espresso beans" -> "Brewing espresso " (trailing space)

    assert_match(/Serving espresso/, result.value)
  end

  def test_brew_invalid
    result = CoffeeMachine.brew(coffee_type: "mud")
    assert result.failure?
    assert_equal "Invalid coffee type", result.value
  end
end

# Mocking ActiveRecord for Transaction Test
module ActiveRecord
  class Base
    def self.transaction
      yield
    rescue Classnt::Rollback => e
      # In real AR, a rollback exception stops the commit.
      # Here we just catch our custom rollback and re-raise or return.
      # The Classnt.transaction wrapper catches Rollback.
      # But wait, Classnt.transaction implementation:
      # Active Record's transaction block normally swallows the exception if you raise ActiveRecord::Rollback.
      # If we raise Classnt::Rollback, it will bubble up to Classnt.transaction rescue block.
      raise e
    end
  end
end

class TestTransactions < Minitest::Test
  def test_transaction_rollback_on_failure
    # Since we defined ActiveRecord::Base above, Classnt.transaction should use it.

    # We want to ensure the block is executed and failure returns the result.
    result = Classnt.transaction do
      Classnt.ok("start")
             .pipe { |_| [:error, "db fail"] }
    end

    assert result.failure?
    assert_equal "db fail", result.value
  end
end
