# frozen_string_literal: true

class ComplexityRequest < ApplicationRecord
  enum :status, {
    pending: "pending",
    in_progress: "in_progress",
    completed: "completed",
    failed: "failed"
  }

  def start!
    with_lock do
      next false unless pending?

      update!(status: :in_progress)
    end
  end

  def complete!(result:, word_errors:)
    with_lock do
      next false unless in_progress?

      update!(status: :completed, result: result, word_errors: word_errors)
    end
  end

  def fail!(from: %w[pending in_progress])
    with_lock do
      next false unless from.include?(status)

      update!(status: :failed, error: "processing_failed")
    end
  end
end
