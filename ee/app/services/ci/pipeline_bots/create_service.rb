# frozen_string_literal: true

module Ci
  module PipelineBots
    class CreateService
      include Gitlab::Utils::StrongMemoize

      def initialize(project, current_user, params = {})
        @project = project
        @current_user = current_user
        @params = params
      end

      def execute
        if Feature.disabled?(:create_and_use_ci_pipeline_bots, project)
          return ServiceResponse.error(message: "Feature flag create_and_use_ci_pipeline_bots is disabled")
        end

        return feature_not_available unless project.licensed_feature_available?(:ci_pipeline_bots)

        unless current_user.can?(:admin_ci_pipeline_bots, project)
          return ServiceResponse.error(
            message: "User does not have permission to create pipeline bots",
            reason: :unauthorized
          )
        end

        return ServiceResponse.error(message: "Bot must have either Developer or Maintainer permissions") unless [
          Gitlab::Access::DEVELOPER, Gitlab::Access::MAINTAINER
        ].include?(params[:access_level])

        user_response = ::Users::AuthorizedCreateService.new(current_user, default_ci_user_params).execute

        return ServiceResponse.error(message: user_response.message) if user_response.error?

        created_user = user_response.payload[:user]
        member = project.add_member(created_user, params[:access_level])

        if member.persisted?
          ServiceResponse.success(payload: { user: created_user })
        else
          delete_failed_user(created_user)
          ServiceResponse.error(
            message: "Could not associate pipeline bot to project. ERROR: #{member.errors.full_messages.to_sentence}"
          )
        end
      end

      private

      attr_accessor :project, :current_user, :params

      def feature_not_available
        ServiceResponse.error(message: "Pipeline bots feature not available")
      end

      def delete_failed_user(user)
        DeleteUserWorker.perform_async(
          current_user.id,
          user.id,
          hard_delete: true,
          skip_authorization: true,
          reason_for_deletion: "Pipeline bot creation failed"
        )
      end

      def username_and_email_generator
        Gitlab::Utils::UsernameAndEmailGenerator.new(
          username_prefix: "project_#{project.id}_pipeline_bot",
          email_domain: "noreply.#{Gitlab.config.gitlab.host}"
        )
      end
      strong_memoize_attr :username_and_email_generator

      def default_ci_user_params
        {
          name: params[:name] || "ci pipelines bot",
          email: username_and_email_generator.email,
          username: username_and_email_generator.username,
          user_type: :ci_pipeline_bot,
          skip_confirmation: true, # Bot users should always have their emails confirmed.
          organization_id: project.organization_id,
          bot_namespace: project.project_namespace
        }
      end
    end
  end
end
