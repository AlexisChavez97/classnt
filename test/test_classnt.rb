# frozen_string_literal: true

require "test_helper"

class TestClassnt < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Classnt::VERSION
  end

  def test_basic_pipeline_success
    result = Classnt.pipe("espresso")
                    .then { |value| [:ok, "#{value} ground"] }
                    .then { |value| [:ok, "#{value} brewed"] }

    assert_predicate result, :ok?
    assert_equal "espresso ground brewed", result.value
  end

  def test_basic_pipeline_failure
    result = Classnt.pipe("espresso")
                    .then { |_value| [:error, "grinder jammed"] }
                    .then { |_value| [:ok, "should not happen"] }

    assert_predicate result, :failure?
    assert_equal "grinder jammed", result.value
  end

  def test_pipeline_with_methods
    # Testing .then(method(:name))
    tester = Object.new
    def tester.step1(value)
      [:ok, value + 1]
    end

    def tester.step2(value)
      [:ok, value * 2]
    end

    result = Classnt.pipe(1)
                    .then(tester.method(:step1))
                    .then(tester.method(:step2))

    assert_equal 4, result.value
  end

  def test_pattern_matching
    result = Classnt.ok("matched")

    case result
    in [:ok, val]
      assert_equal "matched", val
    else
      flunk "Pattern matching failed for array style"
    end

    case result
    in { type: :ok, value: val }
      assert_equal "matched", val
    else
      flunk "Pattern matching failed for hash style"
    end
  end

  def test_side_effects
    side_effect = nil
    result = Classnt.ok("val")
                    .on_success { |v| side_effect = "ok: #{v}" }
                    .on_failure { |_| side_effect = "fail" }

    assert_equal "ok: val", side_effect
    assert_equal result, result # Ensure chaining returns self

    side_effect = nil
    Classnt.error("err")
           .on_success { |_| side_effect = "ok" }
           .on_failure { |v| side_effect = "fail: #{v}" }

    assert_equal "fail: err", side_effect
  end

  def test_unsafe_unwrap
    result = Classnt.ok("success")
    assert_equal "success", result.value!

    error = Classnt.error("boom")
    assert_raises(Classnt::UnwrapError) { error.value! }

    begin
      error.value!
    rescue Classnt::UnwrapError => e
      assert_equal "boom", e.result_value
    end
  end
end
