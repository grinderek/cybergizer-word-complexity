# frozen_string_literal: true

describe ComplexityScores::CalculateJob do
  subject(:job) { described_class.new }

  let(:task) { ComplexityRequest.create!(words: %w[angry qzxqzx]) }
  let(:calculator) { instance_double(ComplexityScores::CalculateWord) }

  before do
    allow(ComplexityScores::CalculateWord).to receive(:new).and_return(calculator)
  end

  it "completes a task with both scores and individual word errors" do
    allow(calculator).to receive(:call).with("angry").and_return("score" => 1.7)
    allow(calculator).to receive(:call).with("qzxqzx").and_return("error" => "no_definitions")

    job.perform(task.id)

    expect(task.reload).to have_attributes(
      status: "completed",
      result: { "angry" => 1.7 },
      word_errors: { "qzxqzx" => "no_definitions" }
    )
  end

  it "completes a task with an empty result when every word has a dictionary error" do
    allow(calculator).to receive(:call).and_return("error" => "no_definitions")

    job.perform(task.id)

    expect(task.reload).to have_attributes(
      status: "completed",
      result: {},
      word_errors: {
        "angry" => "no_definitions",
        "qzxqzx" => "no_definitions"
      }
    )
  end

  it "marks the task as failed and propagates an unexpected exception" do
    allow(calculator).to receive(:call).and_raise(RuntimeError, "Calculation failed")

    expect {
      job.perform(task.id)
    }.to raise_error(RuntimeError, "Calculation failed")

    expect(task.reload).to have_attributes(
      status: "failed",
      error: "processing_failed"
    )
  end

  it "preserves a completed task without recalculating its words" do
    task.update!(
      status: :completed,
      result: { "angry" => 1.7 },
      word_errors: { "qzxqzx" => "no_definitions" }
    )

    job.perform(task.id)

    expect(ComplexityScores::CalculateWord).not_to have_received(:new)
    expect(task.reload).to have_attributes(
      status: "completed",
      result: { "angry" => 1.7 },
      word_errors: { "qzxqzx" => "no_definitions" }
    )
  end
end
