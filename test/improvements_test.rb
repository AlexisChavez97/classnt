# frozen_string_literal: true

require "test_helper"

class TestImprovements < Minitest::Test
  module TestService
    extend Classnt::Pipeline

    pipeline :process_map, transaction: false do
      step :upcase_val, map: true
    end

    pipeline :process_unsafe, transaction: false do
      step :crash_it
    end

    pipeline :process_safe, transaction: false, safe: true do
      step :crash_it
    end

    def upcase_val(val)
      val.upcase
    end

    def crash_it(_val)
      raise "Boom"
    end
  end

  def test_map_step
    result = TestService.process_map("hello")
    assert_predicate result, :ok?
    assert_equal "HELLO", result.value
  end

  def test_result_map
    result = Classnt.ok("hello")
    mapped = result.map { |v| v.upcase }

    assert_predicate mapped, :ok?
    assert_equal "HELLO", mapped.value

    # Test that failure is propagated without mapping
    error = Classnt.error("oops")
    mapped_error = error.map { |v| v.upcase }
    assert_predicate mapped_error, :failure?
    assert_equal "oops", mapped_error.value
  end

  def test_safe_mode
    # process_unsafe should raise
    assert_raises(RuntimeError) { TestService.process_unsafe("go") }

    # process_safe should return error result
    result = TestService.process_safe("go")
    assert_predicate result, :failure?
    assert_equal "Boom", result.value
  end

  def test_transaction_warning
    # Ensure it runs without error (warning will be printed to stderr)
    result = Classnt.transaction { [:ok, 1] }
    assert_equal [:ok, 1], result
  end
end
