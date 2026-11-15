# frozen_string_literal: true

RSpec.describe Bard::ExceptionNotification::Test do
  describe "the test page" do
    it "is not reachable over HTTP" do
      env = request "/exception_notification/test"

      expect(env["action_dispatch.exception"]).to be_a ActionController::RoutingError
      expect(deliveries).to be_empty
    end
  end

  describe "exception_notification:test:web" do
    it "sends a notification from a web request" do
      expect { Rake::Task["exception_notification:test:web"].execute }.to output("web: sent a Bard::ExceptionNotification::TestError notification from Bard::ExceptionNotification::TestsController\n").to_stdout

      expect(deliveries.size).to eq 1
      expect(deliveries.first.subject).to start_with "[dummy] tests#show (Bard::ExceptionNotification::TestError)"
    end

    it "fails when the notification is ignored" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("staging"))

      expect { described_class.web }.to raise_error(/was not sent/)
    end

    it "fails when the notification is ignored and the error page is the detailed development one" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("development"))
      allow(Rails.application).to receive(:env_config).and_wrap_original do |original|
        original.call.merge("action_dispatch.show_detailed_exceptions" => true)
      end

      expect { described_class.web }.to raise_error(/was not sent/)
    end

    it "fails when the request never reaches the test page" do
      allow(described_class).to receive(:host).and_return("blocked.test")

      expect { described_class.web }.to raise_error("Expected the test page to raise Bard::ExceptionNotification::TestError, but it responded 403")
    end

    it "fails when the notification can't be delivered" do
      allow_any_instance_of(ExceptionNotifier::EmailNotifier).to receive(:call).and_raise(Errno::ECONNREFUSED)

      expect { described_class.web }.to raise_error(Errno::ECONNREFUSED)
    end
  end

  describe "exception_notification:test:job" do
    include ActiveJob::TestHelper

    it "enqueues a job that fails and sends a notification" do
      expect { Rake::Task["exception_notification:test:job"].execute }.to output(/job: enqueued/).to_stdout
      expect(enqueued_jobs.map { _1["job_class"] }).to eq ["Bard::ExceptionNotification::TestJob"]

      expect { perform_enqueued_jobs }.to raise_error(Bard::ExceptionNotification::TestError)
      expect(deliveries.size).to eq 1
    end
  end

  describe "exception_notification:test:rake" do
    it "fails the task and sends a notification" do
      expect { Rake::Task["exception_notification:test:rake"].execute }.to raise_error(Bard::ExceptionNotification::TestError, /from rake/)

      expect(deliveries.size).to eq 1
    end
  end

  it "runs the web and job checks before the rake one, which aborts" do
    expect(Rake::Task["exception_notification:test"].prerequisites).to eq %w[test:web test:job test:rake]
  end
end
