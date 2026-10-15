# frozen_string_literal: true

describe "Complexity scores", type: :request do
  describe "POST /complexity-score" do
    it "creates a task with normalized unique words and enqueues it" do
      post "/complexity-score",
           params: [" Angry ", "angry", "sad", " "],
           as: :json

      expect(response).to have_http_status(:ok)

      task = ComplexityRequest.find(response.parsed_body.fetch("job_id"))

      expect(task.words).to eq(%w[angry sad])
      expect(task.status).to eq("pending")
      expect(ComplexityScores::CalculateJob.jobs.size).to eq(1)
      expect(ComplexityScores::CalculateJob.jobs.first.fetch("args")).to eq([task.id])
    end

    it "rejects an empty list without creating a task or enqueuing a job" do
      expect {
        post "/complexity-score", params: [], as: :json
      }.not_to change(ComplexityRequest, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to include("error" => "invalid_input")
      expect(ComplexityScores::CalculateJob.jobs).to be_empty
    end

    it "rejects non-string elements without creating a task or enqueuing a job" do
      expect {
        post "/complexity-score", params: ["angry", 42], as: :json
      }.not_to change(ComplexityRequest, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to include("error" => "invalid_input")
      expect(ComplexityScores::CalculateJob.jobs).to be_empty
    end

    it "returns 503 and marks the task as failed when enqueueing is rejected" do
      allow(ComplexityScores::CalculateJob)
        .to receive(:perform_async)
        .and_return(nil)

      expect {
        post "/complexity-score", params: ["angry"], as: :json
      }.to change(ComplexityRequest, :count).by(1)

      expect(response).to have_http_status(:service_unavailable)
      expect(response.parsed_body).to eq("error" => "queue_unavailable")
      expect(ComplexityRequest.last).to have_attributes(
        status: "failed",
        error: "processing_failed"
      )
    end
  end

  describe "GET /complexity-score/:job_id" do
    let(:task) do
      ComplexityRequest.create!(words: %w[angry qzxqzx])
    end

    it "returns only the status while processing" do
      task.start!

      get "/complexity-score/#{task.id}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("status" => "in_progress")
    end

    it "returns completed results and individual word errors" do
      task.update!(
        status: :completed,
        result: { "angry" => 7.5 },
        word_errors: { "qzxqzx" => "no_definitions" }
      )

      get "/complexity-score/#{task.id}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "status" => "completed",
        "result" => { "angry" => 7.5 },
        "errors" => { "qzxqzx" => "no_definitions" }
      )
    end

    it "returns a failed task with HTTP 200" do
      task.update!(status: :failed, error: "processing_failed")

      get "/complexity-score/#{task.id}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "status" => "failed",
        "error" => "processing_failed"
      )
    end

    it "returns 404 for an unknown task" do
      get "/complexity-score/#{SecureRandom.uuid}"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq("error" => "job_not_found")
    end
  end
end
