# frozen_string_literal: true

module GitlabSubscriptions
  module SelfManaged
    class CreateTrialService
      def initialize(params:, user:)
        @params = params
        @user = user
      end

      def execute
        # TODO: Implement trial submission to CustomersDot API
        # See https://gitlab.com/gitlab-org/gitlab/-/issues/585721
        ServiceResponse.error(message: 'Not implemented', payload: {})
      end
    end
  end
end
