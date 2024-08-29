# frozen_string_literal: true

module Registrations
  class BaseNamespaceCreateService
    include BaseServiceUtility
    include Gitlab::Experiment::Dsl

    def initialize(user, glm_params:, group_params:)
      @user = user
      @glm_params = glm_params.dup
      @group_params = group_params.dup
    end

    private

    attr_reader :user, :glm_params, :project, :group, :group_params

    def after_successful_group_creation(group_track_action:)
      ::Groups::CreateEventWorker.perform_async(group.id, user.id, :created)
      Gitlab::Tracking.event(self.class.name, group_track_action, namespace: group, user: user)
      ::Onboarding::Progress.onboard(group)

      apply_trial if onboarding_status.apply_trial?
    end

    def modified_group_params
      @group_params[:setup_for_company] = user.setup_for_company

      return group_params unless group_needs_path_added?

      group_params
        .compact_blank
        .with_defaults(path: Namespace.clean_path(group_name))
    end

    def apply_trial
      trial_user_information = glm_params.merge(namespace_id: group.id, gitlab_com_trial: true, sync_to_gl: true)
      trial_user_information[:namespace] = group.slice(:id, :name, :path, :kind, :trial_ends_on)

      GitlabSubscriptions::Trials::ApplyTrialWorker.perform_async(user.id, trial_user_information.to_h)
    end

    def group_needs_path_added?
      group_name.present? && group_path.blank?
    end

    def group_name
      group_params[:name]
    end

    def group_path
      group_params[:path]
    end

    def onboarding_status
      @onboarding_status ||= ::Onboarding::Status.new({}, nil, user)
    end
  end
end
