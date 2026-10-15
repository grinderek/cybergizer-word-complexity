# frozen_string_literal: true

describe ComplexityRequest, type: :model do
  describe "#start!" do
    self.use_transactional_tests = false

    it "allows only one of two concurrent executions to start the task" do
      task = described_class.create!(words: ["angry"])
      ready = Queue.new
      start = Queue.new

      threads = Array.new(2) do
        Thread.new do
          Rails.application.executor.wrap do
            described_class.connection_pool.with_connection do
              candidate = described_class.find(task.id)
              ready << true
              start.pop
              candidate.start!
            end
          end
        end
      end

      2.times { expect(ready.pop(timeout: 5)).to be(true) }
      2.times { start << true }
      threads.each { |thread| expect(thread.join(5)).to eq(thread) }

      expect(threads.map(&:value)).to contain_exactly(true, false)
      expect(task.reload.status).to eq("in_progress")
    ensure
      threads&.each do |thread|
        thread.kill if thread.alive?
        thread.join
      end
      task&.destroy!
    end
  end

  it "does not overwrite a completed task with another completion or failure" do
    task = described_class.create!(
      words: %w[angry qzxqzx],
      status: :completed,
      result: { "angry" => 1.7 },
      word_errors: { "qzxqzx" => "no_definitions" }
    )

    expect(task.complete!(result: { "angry" => 99.0 }, word_errors: {})).to be(false)
    expect(task.fail!).to be(false)
    expect(task.reload).to have_attributes(
      status: "completed",
      result: { "angry" => 1.7 },
      word_errors: { "qzxqzx" => "no_definitions" },
      error: nil
    )
  end
end
