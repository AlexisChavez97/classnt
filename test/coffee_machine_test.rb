# frozen_string_literal: true

require "test_helper"
require_relative "coffee_machine"

class CoffeeMachineTest < Minitest::Test
  def test_brew_espresso
    result = CoffeeMachine.brew("espresso")

    assert_predicate result, :ok?
    assert_match(/Serving espresso/, result.value)
  end

  def test_brew_invalid
    result = CoffeeMachine.brew("mud")
    assert_predicate result, :failure?
    assert_equal "Invalid coffee type", result.value
  end
end
