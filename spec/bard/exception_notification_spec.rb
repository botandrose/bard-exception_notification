# frozen_string_literal: true

RSpec.describe Bard::ExceptionNotification do
  describe "web requests" do
    it "emails the exception with the app's name in the subject" do
      request "/boom"

      expect(deliveries.size).to eq 1
      mail = deliveries.first
      expect(mail.subject).to eq %([dummy] boom#show (RuntimeError) "boom")
      expect(mail.to).to eq ["micah@botandrose.com"]
      expect(mail.from).to eq ["errors@bardtracker.com"]
    end

    it "keeps cookies, credentials and the session out of the email" do
      _status, headers, _body = Rails.application.call(Rack::MockRequest.env_for("/login", "HTTP_HOST" => "dummy.test"))
      session_cookie = headers["set-cookie"][/\A[^;]+/]

      request "/boom", "HTTP_COOKIE" => session_cookie, "HTTP_AUTHORIZATION" => "Bearer sekritbearertoken"

      body = deliveries.first.body.to_s
      expect(body).not_to include "sekrit", session_cookie.split("=").last
      expect(body).to match(/HTTP_COOKIE\s*: \[FILTERED\]/)
      expect(body).to match(/rack\.request\.cookie_hash\s*: \[FILTERED\]/)
      expect(body).to match(/rack\.request\.cookie_string\s*: \[FILTERED\]/)
      expect(body).to match(/action_dispatch\.request\.unsigned_session_cookie\s*: \[FILTERED\]/)
      expect(body).not_to match(/^Session:$/)
    end

    it "sends nothing outside production" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("staging"))

      request "/boom"

      expect(deliveries).to be_empty
    end

    it "ignores requests with invalid UTF-8" do
      request "/bad_utf8"

      expect(deliveries).to be_empty
    end
  end

  describe "app initializers" do
    it "can add to the defaults rather than replace them" do
      expect(ExceptionNotifier.ignored_exceptions).to include("Dummy::IgnoredError", "ActionController::InvalidAuthenticityToken", "ActiveRecord::RecordNotFound")
    end

    it "can override the email options" do
      expect(ExceptionNotifier.registered_exception_notifier(:email).base_options).to include(delivery_method: :test, email_prefix: "[dummy] ")
    end
  end

  describe "jobs" do
    class FailingJob < ApplicationJob
      def perform(argument) = raise("job boom")
    end

    class RetryingJob < ApplicationJob
      retry_on RuntimeError, attempts: 2, wait: 0
      def perform = raise("retry boom")
    end

    class DiscardingJob < ApplicationJob
      discard_on RuntimeError
      def perform = raise("discard boom")
    end

    it "emails a job's exception with the job's details" do
      expect { FailingJob.perform_now("an argument") }.to raise_error("job boom")

      expect(deliveries.size).to eq 1
      body = deliveries.first.body.to_s
      expect(body).to include "job boom", "FailingJob", "an argument"
    end

    it "emails only once retries are exhausted" do
      job = RetryingJob.new
      job.perform_now
      expect(deliveries).to be_empty

      expect { job.perform_now }.to raise_error("retry boom")
      expect(deliveries.size).to eq 1
    end

    it "sends nothing for a discarded job" do
      DiscardingJob.perform_now

      expect(deliveries).to be_empty
    end
  end

  describe "rake" do
    it "emails a failing task's exception once" do
      Rake::Task.define_task(:failing_task) { raise "rake boom" }

      expect { Rake::Task[:failing_task].invoke }.to raise_error("rake boom")

      expect(deliveries.size).to eq 1
      expect(deliveries.first.subject).to include "rake boom"
    end

    it "emails an unknown task" do
      expect { Rake.application.invoke_task("no_such_task") }.to raise_error(RuntimeError, /Don't know how to build task/)

      expect(deliveries.size).to eq 1
    end
  end

  describe "ActionController::Live" do
    class LiveController < ActionController::Base
      include ActionController::Live

      def show
        response.stream.write "partial"
        raise "live boom"
      end
    end

    before do
      Rails.application.routes.prepend { get "/live", to: "live#show" }
      Rails.application.reload_routes!
    end

    it "emails an exception raised after the response started streaming" do
      request "/live"

      expect(deliveries.map(&:subject)).to include a_string_including("live boom")
    end
  end
end
