# frozen_string_literal: true

module ComplexityScores
  class CalculateWord
    def initialize(client: Datamuse::Client.new)
      @client = client
    end

    def call(word)
      cached_score = ScoreCache.read(word)
      return { "score" => cached_score } unless cached_score.nil?

      definitions = @client.definition_count(word)
      synonyms = @client.synonym_count(word)
      antonyms = @client.antonym_count(word)
      score = ((synonyms + antonyms) / definitions.to_f).round(1)

      ScoreCache.write(word, score)
      { "score" => score }
    rescue Datamuse::Client::Error => error
      { "error" => error.message }
    end
  end
end
