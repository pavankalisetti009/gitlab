# frozen_string_literal: true

module Ai
  module AmazonQ
    class ServiceAccountMemberAddService
      def initialize(project)
        @project = project
      end

      def execute
        q_user_id = Ai::Setting.instance.amazon_q_service_account_user_id

        existing_member = project.member(q_user_id)
        return ServiceResponse.success(message: "Membership already exists. Nothing to do.") if existing_member

        existing_user = User.find_by_id(q_user_id)
        return ServiceResponse.error(message: "Service account user not found") unless existing_user

        result = project.add_developer(existing_user)
        ServiceResponse.success(payload: result)
      end

      private

      attr_reader :project
    end
  end
end
