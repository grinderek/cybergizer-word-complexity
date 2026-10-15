class ApplicationController < ActionController::API
  rescue_from ActionDispatch::Http::Parameters::ParseError do
    render json: { error: "invalid_json" }, status: :bad_request
  end

  rescue_from ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionFailed,
    RedisClient::ConnectionError, ConnectionPool::TimeoutError do |error|
    Rails.logger.error("Storage request failed: #{error.class}")
    render json: { error: "storage_unavailable" }, status: :service_unavailable
  end
end
