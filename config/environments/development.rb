Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true
  config.active_support.deprecation = :log
  config.action_controller.raise_on_missing_callback_actions = true
  config.logger = ActiveSupport::TaggedLogging.logger(STDOUT) if ENV["RAILS_LOG_TO_STDOUT"] == "1"
end
