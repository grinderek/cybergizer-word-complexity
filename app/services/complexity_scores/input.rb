# frozen_string_literal: true

module ComplexityScores
  class Input
    include ActiveModel::Model

    attr_accessor :payload

    validate :validate_payload

    def words
      return [] unless string_array?

      payload.map { |word| word.strip.downcase }
             .reject(&:empty?)
             .uniq
    end

    private

    def string_array?
      payload.is_a?(Array) &&
        payload.all? { |word| word.is_a?(String) }
    end

    def validate_payload
      if !string_array?
        errors.add(:base, "Expected a JSON array of strings")
      elsif words.empty?
        errors.add(:base, "No words to process")
      end
    end
  end
end
