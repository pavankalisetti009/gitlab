# frozen_string_literal: true

module SecretsManagement
  module Concerns
    module SecretsCountService
      extend ActiveSupport::Concern

      def execute
        current_secrets_count
      end
    end
  end
end
