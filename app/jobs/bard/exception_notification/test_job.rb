# frozen_string_literal: true

module Bard
  module ExceptionNotification
    class TestJob < ::ApplicationJob
      def perform(message)
        raise TestError, message
      end
    end
  end
end
