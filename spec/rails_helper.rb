# frozen_string_literal: true

require "spec_helper"

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("Run specs with RAILS_ENV=test") unless Rails.env.test?

require "rspec/rails"
require "webmock/rspec"

WebMock.disable_net_connect!

ActiveRecord::Migration.maintain_test_schema!
Sidekiq.testing!(:fake)

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.filter_rails_from_backtrace!

  config.before do
    Sidekiq::Job.clear_all
  end
end
