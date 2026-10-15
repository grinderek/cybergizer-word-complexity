# frozen_string_literal: true

module ComplexityScores
  class Submit
    class QueueUnavailable < StandardError; end

    def self.call(words)
      request = ComplexityRequest.create!(words: words)
      raise QueueUnavailable unless CalculateJob.perform_async(request.id)

      request.id
    rescue StandardError
      mark_failed(request) if request
      raise
    end

    def self.mark_failed(request)
      request.fail!(from: %w[pending])
    rescue ActiveRecord::ActiveRecordError => error
      Rails.logger.error("Could not mark unqueued job #{request.id} as failed: #{error.class}")
    end
    private_class_method :mark_failed
  end
end
