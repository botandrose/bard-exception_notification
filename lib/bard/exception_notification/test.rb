# frozen_string_literal: true

require "open3"

module Bard
  module ExceptionNotification
    class TestError < StandardError; end

    module Test
      # Set only in-process, so no HTTP request can reach the test page.
      ENV_KEY = "bard.exception_notification.test"
      SENT_MARKER = "exception_notification: sent"

      extend self

      def web
        surface_delivery_failures!
        env = ::Rack::MockRequest.env_for("https://#{host}/exception_notification/test", "HTTP_HOST" => host, ENV_KEY => true)
        status, _headers, body = ::Rails.application.call(env)
        body.close if body.respond_to?(:close)

        raise "Expected the test page to raise #{TestError}, but it responded #{status}" unless env["action_controller.instance"].is_a?(TestsController)

        exception = env["action_dispatch.exception"]
        raise exception if exception && !exception.is_a?(TestError)
        raise "#{TestError} from the test page was not sent; check ExceptionNotification's ignore rules" unless env["exception_notifier.delivered"]
        puts "web: sent a #{TestError} notification from #{TestsController}"
      end

      def job
        TestJob.perform_later(message("job"))
        puts "job: enqueued #{TestJob}; its notification is sent once the job fails for good, after any retries ApplicationJob configures"
      end

      # A rake notification needs an exception to escape a task, so it's raised in a child process to let this one exit 0.
      def rake
        output, _status = Open3.capture2e(::Rails.root.join("bin/rails").to_s, "exception_notification:test:raise", chdir: ::Rails.root.to_s)
        raise "The rake task's #{TestError} notification was not sent:\n#{output}" unless output.include?(SENT_MARKER)
        puts "rake: sent a #{TestError} notification from a failing rake task"
      end

      # Registered last, this notifier runs only once the others have delivered without raising.
      def raise_from_rake
        surface_delivery_failures!
        ExceptionNotifier.register_exception_notifier(:bard_test_sent, ->(_exception, _options) { warn SENT_MARKER })
        raise TestError, message("rake")
      end

      def message(context)
        "Exception notification test from #{context} at #{Time.now.utc.iso8601}"
      end

      private

      # Otherwise ExceptionNotifier only logs a failed delivery, and the test looks like it passed.
      def surface_delivery_failures!
        ExceptionNotifier.testing_mode = true
      end

      def host
        ::Rails.application.default_url_options.fetch(:host, "localhost")
      end
    end
  end
end
