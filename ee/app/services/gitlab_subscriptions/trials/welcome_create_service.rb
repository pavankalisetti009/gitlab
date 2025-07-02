# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class WelcomeCreateService
      def initialize(params:, user:)
        @params = params
        @user = user
      end

      def execute
        @namespace = create_group
        create_project

        submit_lead
        add_on_purchase = submit_trial
        ServiceResponse.success(
          message: 'Trial applied',
          payload: { namespace_id: namespace.id, add_on_purchase: add_on_purchase }
        )
      end

      private

      attr_reader :user, :params, :namespace

      def create_group
        name = ActionController::Base.helpers.sanitize(params[:group_name])
        group_params = {
          name: name,
          path: Namespace.clean_path(name.parameterize),
          organization_id: params[:organization_id]
        }

        response = Groups::CreateService.new(user, group_params).execute
        namespace = response[:group]

        # We need to stick to the primary database in order to allow the following request
        # fetch the namespace from an up-to-date replica or a primary database.
        ::Namespace.sticking.stick(:namespace, namespace.id) if response.success?
        namespace
      end

      def create_project
        project_params = {
          name: ActionController::Base.helpers.sanitize(params[:project_name]),
          namespace_id: namespace.id,
          organization_id: namespace.organization_id
        }

        Projects::CreateService.new(user, project_params).execute
      end

      def submit_lead
        GitlabSubscriptions::CreateLeadService.new.execute(trial_user: lead_params)
      end

      def submit_trial
        result = GitlabSubscriptions::Trials::ApplyTrialService.new(uid: user.id,
          trial_user_information: trial_params).execute
        result[:add_on_purchase]
      end

      def trial_params
        gl_com_params = { gitlab_com_trial: true, sync_to_gl: true }
        namespace_params = {
          namespace_id: namespace.id,
          namespace: namespace.slice(:id, :name, :path, :kind, :trial_ends_on).merge(plan: namespace.actual_plan.name)
        }

        params.slice(*::Onboarding::StatusPresenter::GLM_PARAMS, :namespace_id)
              .merge(gl_com_params, namespace_params).to_h.symbolize_keys
      end

      def lead_params
        attrs = {
          work_email: user.email,
          uid: user.id,
          setup_for_company: false,
          skip_email_confirmation: true,
          gitlab_com_trial: true,
          provider: 'gitlab'
        }

        params.slice(
          *::Onboarding::StatusPresenter::GLM_PARAMS,
          :company_name, :first_name, :last_name, :country, :state
        ).merge(attrs)
      end
    end
  end
end
