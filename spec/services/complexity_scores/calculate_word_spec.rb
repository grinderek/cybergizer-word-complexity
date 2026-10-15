# frozen_string_literal: true

describe ComplexityScores::CalculateWord do
  subject(:calculator) { described_class.new(client: client) }

  let(:client) { instance_double(Datamuse::Client) }
  let(:word) { "angry" }

  before do
    allow(ComplexityScores::ScoreCache).to receive(:read).with(word).and_return(nil)
    allow(ComplexityScores::ScoreCache).to receive(:write)
  end

  it "calculates a rounded score on a cache miss and caches it" do
    allow(client).to receive(:definition_count).with(word).and_return(3)
    allow(client).to receive(:synonym_count).with(word).and_return(4)
    allow(client).to receive(:antonym_count).with(word).and_return(1)

    expect(calculator.call(word)).to eq("score" => 1.7)
    expect(ComplexityScores::ScoreCache).to have_received(:write).with(word, 1.7)
  end

  it "returns a cached zero score without calling the dictionary client" do
    allow(ComplexityScores::ScoreCache).to receive(:read).with(word).and_return(0.0)

    expect(calculator.call(word)).to eq("score" => 0.0)
    expect(ComplexityScores::ScoreCache).not_to have_received(:write)
  end

  it "returns a dictionary error without caching it" do
    allow(client).to receive(:definition_count).with(word)
      .and_raise(Datamuse::Client::Error, "no_definitions")

    expect(calculator.call(word)).to eq("error" => "no_definitions")
    expect(ComplexityScores::ScoreCache).not_to have_received(:write)
  end
end
