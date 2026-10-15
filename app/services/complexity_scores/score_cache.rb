# frozen_string_literal: true

module ComplexityScores
  class ScoreCache
    TTL = 24.hours.to_i

    def self.read(word)
      Rails.cache.read(key(word))
    end

    def self.write(word, score)
      Rails.cache.write(key(word), score, expires_in: TTL)
    end

    def self.key(word)
      Digest::SHA256.hexdigest(word)
    end

    private_class_method :key
  end
end
