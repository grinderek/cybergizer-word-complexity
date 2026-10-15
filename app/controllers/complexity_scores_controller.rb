# frozen_string_literal: true

class ComplexityScoresController < ApplicationController
  rescue_from ComplexityScores::Submit::QueueUnavailable do
    render json: { error: "queue_unavailable" }, status: :service_unavailable
  end

  def create
    input = ComplexityScores::Input.new(payload: params[:_json])

    unless input.valid?
      return render json: {
        error: "invalid_input",
        message: input.errors.full_messages.first
      }, status: :unprocessable_content
    end

    job_id = ComplexityScores::Submit.call(input.words)

    render json: { job_id: }, status: :ok
  end

  def show
    complexity_request = ComplexityRequest.find_by(id: params[:job_id])

    unless complexity_request
      return render json: { error: "job_not_found" }, status: :not_found
    end

    if complexity_request.completed?
      render json: {
        status: complexity_request.status,
        result: complexity_request.result,
        errors: complexity_request.word_errors
      }
    elsif complexity_request.failed?
      render json: { status: complexity_request.status, error: complexity_request.error }
    else
      render json: { status: complexity_request.status }
    end
  end
end
