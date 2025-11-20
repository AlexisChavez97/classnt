# frozen_string_literal: true

require "test_helper"

class TestClassnt < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Classnt::VERSION
  end

  def test_basic_pipeline_success
    result = Classnt.pipe("espresso")
                    .then { |v| [:ok, "#{v} ground"] }
                    .then { |v| [:ok, "#{v} brewed"] }

    assert_predicate result, :ok?
    assert_equal "espresso ground brewed", result.value
  end

  def test_basic_pipeline_failure
    result = Classnt.pipe("espresso")
                    .then { |v| [:error, "grinder jammed"] }
                    .then { |v| [:ok, "should not happen"] }

    assert_predicate result, :failure?
    assert_equal "grinder jammed", result.value
  end

  def test_pipeline_with_methods
    # Testing .then(method(:name))
    tester = Object.new
    def tester.step1(v)
      [:ok, v + 1]
    end
    def tester.step2(v)
      [:ok, v * 2]
    end

    result = Classnt.pipe(1)
                    .then(tester.method(:step1))
                    .then(tester.method(:step2))

    assert_equal 4, result.value
  end
end
