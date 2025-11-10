# frozen_string_literal: true

module EE
  module GroupsController
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override
    include GroupInviteMembers

    prepended do
      include GeoInstrumentation
      include GitlabSubscriptions::SeatCountAlert
      include EpicParamActions

      before_action :check_subscription!, only: [:destroy]

      # for general settings certain features can be enabled via custom roles
      skip_before_action :authorize_admin_group!, only: [:edit]
      before_action :authorize_view_edit_page!, only: [:edit]

      # We have to redefine the before_action :enforce_step_up_auth_for_namespace
      # because otherwise it would run before :authorize_view_edit_page!
      # due to the order of before_actions in the inheritance chain.
      # In general, step-up auth should be enforced after authorization checks.
      before_action :enforce_step_up_auth_for_namespace, except: [:index, :new, :create]
      skip_before_action :enforce_step_up_auth_for_namespace, if: :skip_step_up_auth_for_owner_on_edit_and_update?

      before_action do
        push_frontend_feature_flag(:saas_user_caps_auto_approve_pending_users_on_cap_increase, @group)
      end

      before_action only: :issues do
        push_force_frontend_feature_flag(:okrs_mvc, !!@group&.okrs_mvc_feature_flag_enabled?)
      end

      before_action only: :show do
        @seat_count_data = generate_seat_count_alert_data(@group)
      end
    end

    override :render_show_html
    def render_show_html
      if redirect_show_path
        redirect_to redirect_show_path, status: :temporary_redirect
      else
        super
      end
    end

    private

    def check_subscription!
      if group.linked_to_subscription?
        respond_to do |format|
          format.html do
            redirect_to edit_group_path(group),
              status: :found,
              alert: _('This group is linked to a subscription')
          end

          format.json do
            render json: { message: _('This group is linked to a subscription') }, status: :unprocessable_entity
          end
        end
      end
    end

    def redirect_show_path
      strong_memoize(:redirect_show_path) do
        case group_view
        when 'security_dashboard'
          helpers.group_security_dashboard_path(group)
        end
      end
    end

    def group_view
      current_user&.group_view || default_group_view
    end

    def default_group_view
      EE::User::DEFAULT_GROUP_VIEW
    end

    def update_user_setup_for_company
      return if group.setup_for_company.nil? || current_user.onboarding_status_setup_for_company.present?

      ::Users::UpdateService.new(current_user,
        { onboarding_status_setup_for_company: group.setup_for_company }.merge(user: current_user)).execute
    end

    override :successful_creation_hooks
    def successful_creation_hooks
      super
      update_user_setup_for_company

      invite_members(group, invite_source: 'group-creation-page')
    end

    override :redirect_if_epic_params
    def redirect_if_epic_params
      # To handle legacy urls with epic filters, translate these to the parent filter equivalents and redirect
      return unless has_epic_filter?

      redirect_to issues_group_path(group, params: convert_epic_params)

      true
    end

    override :work_items_redirect_params
    def work_items_redirect_params
      if has_epic_filter?
        convert_epic_params
      else
        super
      end
    end
  end
end
