# frozen_string_literal: true

ExceptionNotification.configure do |config|
  config.ignored_exceptions += %w[Dummy::IgnoredError]
  config.add_notifier :email, Bard::ExceptionNotification.email_options.merge(delivery_method: :test)
end
