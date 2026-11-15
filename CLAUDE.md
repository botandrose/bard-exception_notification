# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Rails engine gem that gives every BARD-managed Rails app the same exception_notification setup: email notifications for web requests, ActiveJob, rake tasks and `ActionController::Live`, plus `rake exception_notification:test` to verify delivery end to end in a deployed app.

## Commands

- Full suite (fast, under a second): `bundle exec rspec` (also `bundle exec rake`)
- Single file / example: `bundle exec rspec spec/bard/exception_notification_spec.rb:42`
- Rails matrix (as CI runs it, Ruby 3.2–4.0 × Rails 7.2/8.0/8.1): `bundle exec appraisal install`, then `bundle exec appraisal rails-7.2 rspec`

## Architecture

- `lib/bard/exception_notification.rb` holds the shared pieces: `email_options` (recipient, sender, `[<app dir name>]` subject prefix, SMTP from `credentials.exception_notification_smtp_settings`, and `sections` that deliberately omit `session`), `notify_job_failure`, and three prepend modules (`LiveErrorNotification`, `DelayedJobNotification`, `UnknownTaskNotification`).
- `lib/bard/exception_notification/engine.rb` wires it into the host app:
  - The defaults initializer runs `before: :load_config_initializers`, so a host app's own `ExceptionNotification.configure` can add to (`+=`) or override the defaults. Preserve that ordering.
  - It adds `filter_parameters` for cookie/auth/session env keys so they show as `[FILTERED]` in emails, and ignores everything outside `Rails.env.production?`.
  - Job failures come from a `perform.active_job` notification subscriber, which fires only once retries are exhausted and never for discarded jobs. It skips jobs on the delayed_job adapter, because delayed_job retries those itself.
  - When `Delayed::Worker` is loaded, `DelayedJobNotification` is prepended to it in `after_initialize`, and it notifies only once delayed_job gives up on a job (`job.attempts >= max_attempts(job)` after `super` has rescheduled it).
  - The test route is prepended with a constraint on `Test::ENV_KEY`, an env key set only in-process, so it can't be reached over HTTP.
- `lib/bard/exception_notification/test.rb` + `lib/tasks/exception_notification.rake` implement the end-to-end check. `Test.web` drives `Rails.application.call` with a mock request and inspects `exception_notifier.delivered`. It sets `ExceptionNotifier.testing_mode = true` so delivery failures raise instead of being only logged. The `test` task runs `web`, `job`, and `rake`, and exits 0 when all three succeed. A rake notification needs an exception to escape a task, so `Test.rake` runs the hidden `exception_notification:test:raise` task in a child `bin/rails` process. That task registers a last `:bard_test_sent` lambda notifier, which prints `Test::SENT_MARKER` only if the notifiers before it delivered without raising. The parent then checks the child's output for that marker. When `Delayed::Job` exists, the job check also enqueues `TestDelayedJob`, a plain delayed_job payload with `max_attempts` 1, so its notification doesn't wait out the app's retries. It replaces the ActiveJob check when ActiveJob runs on delayed_job.
- `app/` holds the engine's `TestsController` and `TestJob` (which inherits the host's `::ApplicationJob`, or `ActiveJob::Base` in an app without one).

## Specs

- `spec/spec_helper.rb` defines an inline `Dummy::Application` (root `spec/dummy`), the `/boom` and `/login` routes, and the `request`/`deliveries` helpers. It stubs `Rails.env` to `production` before every example, so notifications fire by default. Tests that need "not production" re-stub it.
- `spec/dummy/config/initializers/exception_notification.rb` acts as a host app's initializer and switches the email notifier to `delivery_method: :test`.
- `module Bard::Rake` is defined in the spec helper on purpose: in real apps, bard-rake makes `Rake` inside `module Bard` resolve to `Bard::Rake`, which is why the engine uses `::Rake`. Keep top-level constants (`::Rails`, `::Rake`, `::ExceptionNotification`) fully qualified inside `module Bard`.
