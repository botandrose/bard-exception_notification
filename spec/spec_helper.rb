# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require "rails"
require "action_controller/railtie"
require "action_mailer/railtie"
require "active_job/railtie"
require "rake"
require "delayed_job"
require "bard-exception_notification"

# Every bard app loads bard-rake, whose Bard::Rake shadows ::Rake inside module Bard.
module Bard::Rake; end

class ApplicationJob < ActiveJob::Base
end

module Dummy
  class Application < Rails::Application
    config.root = File.expand_path("dummy", __dir__)
    config.eager_load = false
    config.secret_key_base = "x" * 64
    config.logger = Logger.new(nil)
    config.action_dispatch.show_exceptions = :all
    config.active_job.queue_adapter = :test
    config.hosts << "dummy.test"
    default_url_options[:host] = "dummy.test"

    routes.append do
      get "/boom", to: "boom#show"
      get "/login", to: "boom#login"
      get "/bad_utf8", to: "boom#bad_utf8"
    end
  end
end

class BoomController < ActionController::Base
  def show
    session[:user_credentials]
    raise "boom"
  end

  def bad_utf8
    raise ArgumentError, "invalid byte sequence in UTF-8"
  end

  def login
    session[:user_credentials] = "sekritpersistencetoken"
    head :ok
  end
end

Dummy::Application.initialize!
Dummy::Application.load_tasks

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }

  config.before do
    ActionMailer::Base.deliveries.clear
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    ExceptionNotifier.testing_mode = false
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))
  end

  config.include Module.new {
    def deliveries = ActionMailer::Base.deliveries

    def request(path, env = {})
      env = Rack::MockRequest.env_for(path, { "HTTP_HOST" => "dummy.test" }.merge(env))
      _status, _headers, body = Rails.application.call(env)
      body.each { } if body.respond_to?(:each)
      body.close if body.respond_to?(:close)
      env
    end
  }
end
