# frozen_string_literal: true

describe Datamuse::Client do
  subject(:client) { described_class.new(base_url: "https://api.datamuse.com") }

  let(:endpoint) { "https://api.datamuse.com/words" }
  let(:word) { "angry" }

  describe "#definition_count" do
    let(:query) { { sp: word, qe: "sp", md: "d", max: "1" } }

    it "counts distinct nonblank definitions after trimming" do
      stub_request(:get, endpoint).with(query: query).to_return_json(
        body: [{ word: word, defs: ["adj\tFeeling anger", " adj\tFeeling anger ", "adj\tShowing anger", " "] }]
      )

      expect(client.definition_count(word)).to eq(2)
    end

    it "raises no_definitions when definitions are missing" do
      stub_request(:get, endpoint).with(query: query).to_return_json(
        body: [{ word: word }]
      )

      expect {
        client.definition_count(word)
      }.to raise_error(Datamuse::Client::Error, "no_definitions")
    end

    it "rejects invalid JSON as dictionary_unavailable" do
      stub_request(:get, endpoint).with(query: query).to_return(body: "not JSON")

      expect {
        client.definition_count(word)
      }.to raise_error(Datamuse::Client::Error, "dictionary_unavailable")
    end

    it "rejects an unexpected response structure as dictionary_unavailable" do
      stub_request(:get, endpoint).with(query: query).to_return_json(
        body: { error: "Unexpected response" }
      )

      expect {
        client.definition_count(word)
      }.to raise_error(Datamuse::Client::Error, "dictionary_unavailable")
    end

    it "converts an unsuccessful HTTP response to dictionary_unavailable" do
      stub_request(:get, endpoint).with(query: query).to_return(status: 503)

      expect {
        client.definition_count(word)
      }.to raise_error(Datamuse::Client::Error, "dictionary_unavailable")
    end

    it "converts an HTTP timeout to dictionary_unavailable" do
      stub_request(:get, endpoint).with(query: query).to_timeout

      expect {
        client.definition_count(word)
      }.to raise_error(Datamuse::Client::Error, "dictionary_unavailable")
    end
  end

  describe "relationship counts" do
    it "normalizes and deduplicates synonyms and antonyms separately" do
      stub_request(:get, endpoint).with(query: { rel_syn: word, max: "1000" }).to_return_json(
        body: [{ word: " Furious " }, { word: "furious" }, { word: "irate" }, { word: " " }]
      )
      stub_request(:get, endpoint).with(query: { rel_ant: word, max: "1000" }).to_return_json(
        body: [{ word: " Calm " }, { word: "calm" }, { word: " " }]
      )

      expect(client.synonym_count(word)).to eq(2)
      expect(client.antonym_count(word)).to eq(1)
    end

    it "returns zero for empty synonym and antonym lists" do
      stub_request(:get, endpoint).with(query: { rel_syn: word, max: "1000" }).to_return_json(body: [])
      stub_request(:get, endpoint).with(query: { rel_ant: word, max: "1000" }).to_return_json(body: [])

      expect(client.synonym_count(word)).to eq(0)
      expect(client.antonym_count(word)).to eq(0)
    end
  end
end
