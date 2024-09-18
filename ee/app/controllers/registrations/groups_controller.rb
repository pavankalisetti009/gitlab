# frozen_string_literal: true

module Registrations
  class GroupsController < ApplicationController
    include OneTrustCSP
    include GoogleAnalyticsCSP
    include GoogleSyndicationCSP
    include ::Onboarding::SetRedirect

    skip_before_action :set_confirm_warning
    before_action :verify_onboarding_enabled!
    before_action :authorize_create_group!, only: :new

    before_action do
      experiment(:project_templates_during_registration, user: current_user).publish
    end

    layout 'minimal'

    feature_category :onboarding

    urgency :low, [:create]

    helper_method :tracking_label

    def new
      @group = Group.new(visibility_level: Gitlab::CurrentSettings.default_group_visibility)
      @project = Project.new(namespace: @group)
      @initialize_with_readme = true

      experiment(:project_templates_during_registration, user: current_user)
        .track(:render_groups_new, label: tracking_label)

      track_event('view_new_group_action', tracking_label)
    end

    def create
      result = service_instance.execute

      if result.success?
        actions_after_success(result.payload)
      else
        @group = result.payload[:group]
        @project = result.payload[:project]

        @group.errors.full_messages.each do |error|
          track_event("track_#{tracking_label}_error", "group_#{error.parameterize.underscore}")
        end

        @project.errors.full_messages.each do |error|
          track_event("track_#{tracking_label}_error", "project_#{error.parameterize.underscore}")
        end

        unless import? # imports do not have project params
          @template_name = project_params[:template_name]
          @initialize_with_readme = project_params[:initialize_with_readme]
        end

        render :new
      end
    end

    private

    def service_instance
      if import?
        Registrations::ImportNamespaceCreateService
          .new(current_user, glm_params: glm_params, group_params: group_params)
      else
        Registrations::StandardNamespaceCreateService
          .new(current_user, glm_params: glm_params, group_params: group_params, project_params: project_params)
      end
    end

    def actions_after_success(payload)
      ::Onboarding::FinishService.new(current_user).execute

      if import?
        import_url = URI.join(root_url, general_params[:import_url], "?namespace_id=#{payload[:group].id}").to_s
        redirect_to import_url
      else
        track_project_registration_submission(payload[:project])

        cookies[:confetti_post_signup] = true

        redirect_to project_learn_gitlab_path(payload[:project])
      end
    end

    def authorize_create_group!
      access_denied! unless can?(current_user, :create_group)
    end

    def import?
      general_params[:import_url].present?
    end

    def tracking_label
      onboarding_status.tracking_label
    end

    def track_event(action, label)
      ::Gitlab::Tracking.event(self.class.name, action, user: current_user, label: label)
    end

    def track_project_registration_submission(project)
      experiment(:project_templates_during_registration, user: current_user).track(:assignment,
        namespace: project.namespace)

      experiment_project_templates_during_registration(
        project,
        :successfully_submitted_form,
        tracking_label
      )

      template_name = project_params[:template_name]
      return if template_name.blank?

      experiment_project_templates_during_registration(
        project,
        "select_project_template_#{template_name}",
        tracking_label
      )
    end

    def experiment_project_templates_during_registration(project, name, label)
      experiment(
        :project_templates_during_registration,
        user: current_user,
        project: project,
        namespace: project.namespace
      ).track(name, label: label)
    end

    def onboarding_status
      ::Onboarding::Status.new({}, session, current_user)
    end
    strong_memoize_attr :onboarding_status

    def group_params
      params.require(:group).permit(
        :id,
        :name,
        :path,
        :visibility_level,
        :organization_id
      ).with_defaults(organization_id: Current.organization_id)
    end

    def project_params
      params.require(:project).permit(
        :initialize_with_readme,
        :name,
        :namespace_id,
        :path,
        :template_name,
        :visibility_level
      )
    end

    def general_params
      params.permit(:import_url).merge(glm_params)
    end

    def glm_params
      params.permit(:glm_source, :glm_content)
    end
  end
end
