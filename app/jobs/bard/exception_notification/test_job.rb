# frozen_string_literal: true

module Bard
  module ExceptionNotification
    # Inherits the app's ApplicationJob, so it fails with the app's own retries, but not every app has one.
    class TestJob < (defined?(::ApplicationJob) ? ::ApplicationJob : ActiveJob::Base)
      def perform(message)
        raise TestError, message
      end
    end
  end
end
