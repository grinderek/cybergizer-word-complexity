# frozen_string_literal: true

module ComplexityScores
  class CalculateJob
    include Sidekiq::Job

    sidekiq_options retry: false

    WORD_CONCURRENCY = Integer(ENV.fetch("WORD_CONCURRENCY", 3))

    def perform(job_id)
      request = ComplexityRequest.find(job_id)
      started = request.start!
      return unless started

      words = request.words
      outcomes = Parallel.map(words, in_threads: WORD_CONCURRENCY) do |word|
        Rails.application.executor.wrap do
          [word, CalculateWord.new.call(word)]
        end
      end

      result = {}
      errors = {}

      outcomes.each do |word, outcome|
        if outcome.key?("score")
          result[word] = outcome.fetch("score")
        else
          errors[word] = outcome.fetch("error")
        end
      end

      request.complete!(result: result, word_errors: errors)
    rescue StandardError
      mark_failed(request) if started
      raise
    end

    private

    def mark_failed(request)
      request.fail!
    rescue ActiveRecord::ActiveRecordError => error
      Rails.logger.error("Could not mark job #{request.id} as failed: #{error.class}")
    end
  end
end
