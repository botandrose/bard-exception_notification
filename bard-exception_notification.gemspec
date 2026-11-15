# frozen_string_literal: true

require_relative "lib/bard/exception_notification/version"

Gem::Specification.new do |spec|
  spec.name = "bard-exception_notification"
  spec.version = Bard::ExceptionNotification::VERSION
  spec.authors = ["Micah Geisel"]
  spec.email = ["micah@botandrose.com"]

  spec.summary = "Shared exception_notification setup for BARD-managed Rails projects"
  spec.description = "Configures exception_notification for web requests, ActiveJob, rake and ActionController::Live, and adds rake exception_notification:test to check it end to end"
  spec.homepage = "https://github.com/botandrose/bard-exception_notification"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git Gemfile])
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "exception_notification", ">= 5.0"
  spec.add_dependency "rails", ">= 7.2"
end
