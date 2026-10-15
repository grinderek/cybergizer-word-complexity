# frozen_string_literal: true

module Datamuse
  class Client
    class Error < StandardError; end

    MAX_RESULTS = 1_000

    def initialize(base_url: ENV.fetch("DATAMUSE_URL", "https://api.datamuse.com"),
                   timeout: Float(ENV.fetch("DATAMUSE_TIMEOUT_SECONDS", 5)))
      @endpoint = "#{base_url}/words"
      @http = HTTP.timeout(timeout).headers(accept: "application/json", user_agent: "WordComplexity/1.0")
    end

    def definition_count(word)
      entry = request(sp: word, qe: "sp", md: "d", max: 1).first
      definitions = entry&.fetch("defs", nil)
      raise Error, "no_definitions" if definitions.nil?

      unless definitions.is_a?(Array) && definitions.all? { |definition| definition.is_a?(String) }
        raise Error, "dictionary_unavailable"
      end

      count = definitions.map(&:strip).reject(&:empty?).uniq.size
      raise Error, "no_definitions" if count.zero?

      count
    end

    def synonym_count(word)
      related_word_count(rel_syn: word)
    end

    def antonym_count(word)
      related_word_count(rel_ant: word)
    end

    private

    def related_word_count(**relation)
      entries = request(**relation, max: MAX_RESULTS)
      entries.map { |item| item.fetch("word").strip.downcase }.reject(&:empty?).uniq.size
    end

    def request(**query)
      response = @http.get(@endpoint, params: query)
      raise Error, "dictionary_unavailable" unless response.status.success?

      data = JSON.parse(response.body.to_s)
      unless data.is_a?(Array) && data.all? { |item| item.is_a?(Hash) && item["word"].is_a?(String) }
        raise Error, "dictionary_unavailable"
      end

      data
    rescue HTTP::Error, JSON::ParserError => error
      Rails.logger.warn("Datamuse request failed: #{error.class}")
      raise Error, "dictionary_unavailable"
    ensure
      @http.close
    end
  end
end
