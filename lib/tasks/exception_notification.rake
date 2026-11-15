# frozen_string_literal: true

namespace :exception_notification do
  desc "Send a test exception notification from a web request, a job and a rake task"
  task test: %w[test:web test:job test:rake]

  namespace :test do
    desc "Send a test exception notification from a web request"
    task web: :environment do
      Bard::ExceptionNotification::Test.web
    end

    desc "Enqueue a job that fails, to send a test exception notification from a job"
    task job: :environment do
      Bard::ExceptionNotification::Test.job
    end

    desc "Send a test exception notification from a rake task"
    task rake: :environment do
      Bard::ExceptionNotification::Test.rake
    end
  end
end
