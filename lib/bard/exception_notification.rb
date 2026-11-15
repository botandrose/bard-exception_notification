# frozen_string_literal: true

require "exception_notification"
require "exception_notification/rails"
require "bard/exception_notification/version"
require "bard/exception_notification/test"
require "bard/exception_notification/engine"

module Bard
  module ExceptionNotification
    def self.email_options
      {
        email_prefix: "[#{::Rails.root.basename}] ",
        exception_recipients: "micah@botandrose.com",
        sender_address: "errors@bardtracker.com",
        sections: %w[request environment backtrace], # not session, which can hold a login's persistence token
        smtp_settings: ::Rails.application.credentials.exception_notification_smtp_settings,
      }
    end

    def self.notify_job_failure(exception, job)
      ExceptionNotifier.notify_exception(exception, data: {
        job_class: job.class.name,
        job_id: job.job_id,
        arguments: job.arguments,
        queue_name: job.queue_name,
        executions: job.executions,
      })
    end

    module LiveErrorNotification
      def log_error(exception)
        ExceptionNotifier.notify_exception(exception, env: request.env)
        super
      end
    end

    module UnknownTaskNotification
      def invoke_task(task_string)
        super
      rescue RuntimeError => exception
        ExceptionNotifier.notify_exception(exception) if exception.message.start_with?("Don't know how to build task")
        raise
      end
    end
  end
end
