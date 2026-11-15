# frozen_string_literal: true

require "rails/engine"

module Bard
  module ExceptionNotification
    class Engine < ::Rails::Engine
      # Before the app's own initializers, so they can adjust any of this with ExceptionNotification.configure.
      initializer "bard-exception_notification.defaults", before: :load_config_initializers do |app|
        app.config.filter_parameters += [
          /\AHTTP_COOKIE\z/,
          /\AHTTP_AUTHORIZATION\z/,
          /\Arack\.request\.cookie_(hash|string)\z/,
          /\Arack\.session\z/,
          /\Aaction_dispatch\.request\.unsigned_session_cookie\z/,
        ]

        ::ExceptionNotification.configure do |config|
          config.ignored_exceptions += %w[
            ActionController::InvalidAuthenticityToken
            ActionView::MissingTemplate
            ActionController::BadRequest
            ActionDispatch::Http::Parameters::ParseError
            Mime::Type::InvalidMimeType
            URI::InvalidComponentError
            Addressable::URI::InvalidURIError
          ]

          config.ignore_if do |exception, options|
            !::Rails.env.production?
          end

          config.ignore_if do |exception, options|
            exception.message == "invalid byte sequence in UTF-8"
          end

          config.add_notifier :email, ExceptionNotification.email_options
        end
      end

      initializer "bard-exception_notification.active_job" do
        ActiveSupport::Notifications.subscribe("perform.active_job") do |event|
          exception = event.payload[:exception_object]
          next unless exception
          # delayed_job retries these jobs itself, and DelayedJobNotification reports the last failure.
          next if event.payload[:adapter].class.name == "ActiveJob::QueueAdapters::DelayedJobAdapter"
          ExceptionNotification.notify_job_failure(exception, event.payload[:job])
        end
      end

      config.after_initialize do
        ::Delayed::Worker.prepend DelayedJobNotification if defined?(::Delayed::Worker)
      end

      initializer "bard-exception_notification.live" do
        ActiveSupport.on_load(:action_controller_base) do
          ActionController::Live.prepend LiveErrorNotification
        end
      end

      initializer "bard-exception_notification.test_route" do |app|
        app.routes.prepend do
          get "/exception_notification/test",
            to: "bard/exception_notification/tests#show",
            as: nil,
            constraints: ->(request) { request.env[Test::ENV_KEY] }
        end
      end

      rake_tasks do
        ::Rake::Application.prepend UnknownTaskNotification
      end
    end
  end
end
