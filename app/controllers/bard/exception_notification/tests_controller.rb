# frozen_string_literal: true

module Bard
  module ExceptionNotification
    class TestsController < ActionController::Base
      def show
        raise TestError, Test.message("web")
      end
    end
  end
end
