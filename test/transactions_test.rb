# frozen_string_literal: true

require "test_helper"

# Mocking ActiveRecord for Transaction Test
module ActiveRecord
  class Base
    def self.transaction
      yield
    rescue Classnt::Rollback => e
      raise e
    end
  end
end

class TransactionsTest < Minitest::Test
  def test_transaction_rollback_on_failure
    # Since we defined ActiveRecord::Base above, Classnt.transaction should use it.

    # We want to ensure the block is executed and failure returns the result.
    result = Classnt.transaction do
      Classnt.pipe("start")
             .then { |_| [:error, "db fail"] }
    end

    assert_predicate result, :failure?
    assert_equal "db fail", result.value
  end
end
