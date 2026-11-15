# bard-exception_notification

Shared [exception_notification](https://rubygems.org/gems/exception_notification) setup for BARD-managed Rails apps. Add the gem and every production app emails its exceptions the same way, from:

- web requests
- ActiveJob jobs, once retries are exhausted (discarded jobs send nothing)
- rake tasks, including unknown task names
- `ActionController::Live` actions that raise after the response has started streaming

It also adds `rake exception_notification:test` to check that notifications actually arrive from a deployed app.

## Installation

```ruby
gem "bard-exception_notification"
```

Requires Ruby 3.2+, Rails 7.2+ and exception_notification 5.0+.

Add SMTP settings to the app's credentials:

```yaml
exception_notification_smtp_settings:
  address: smtp.example.com
  port: 587
  user_name: ...
  password: ...
```

## What it configures

- Emails go to `micah@botandrose.com` from `errors@bardtracker.com`, with the app's directory name as the subject prefix, e.g. `[myapp] `.
- Notifications are sent only in production.
- Common noise is ignored: `ActionController::InvalidAuthenticityToken`, `ActionView::MissingTemplate`, `ActionController::BadRequest`, `ActionDispatch::Http::Parameters::ParseError`, `Mime::Type::InvalidMimeType`, `URI::InvalidComponentError` and `Addressable::URI::InvalidURIError`.
- Cookies, the `Authorization` header and the session are kept out of emails. They are added to `filter_parameters`, and the session section is left out.

## Customizing

The defaults are applied before the app's own initializers, so an initializer can add to them or override them:

```ruby
# config/initializers/exception_notification.rb
ExceptionNotification.configure do |config|
  config.ignored_exceptions += %w[MyApp::ExpectedError]
  config.add_notifier :email, Bard::ExceptionNotification.email_options.merge(exception_recipients: "team@example.com")
end
```

## Testing a deployed app

```sh
bin/rake exception_notification:test
```

This runs three checks in order:

- `exception_notification:test:web` sends a request through the app's middleware stack to a test page that raises, then fails unless a notification was delivered. The page is reachable only from this task, never over HTTP. The request uses the host from `Rails.application.default_url_options`, so that host must be allowed by `config.hosts`.
- `exception_notification:test:job` enqueues a job that raises. Its notification is sent once a worker runs the job and any retries configured by `ApplicationJob` are exhausted.
- `exception_notification:test:rake` runs `bin/rails exception_notification:test:raise` in a child process, which fails by raising so that its notification goes out, and then checks that the notification was sent.

The command exits 0 once the web and rake notifications are sent and the job is enqueued. The web and rake checks fail if a notification is ignored or can't be delivered, instead of only logging the failure.

## Development

```sh
bundle install
bundle exec rspec
bundle exec appraisal install && bundle exec appraisal rspec   # every supported Rails version
```

## License

MIT
