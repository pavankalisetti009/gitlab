# frozen_string_literal: true

module EE
  module PageLayoutHelper
    VALID_DUO_ADD_ONS = %w[duo_enterprise duo_pro duo_core].freeze
    VALID_DUO_CORE = %w[duo_core].freeze
    DEFAULT_TRIAL_DURATION = 30

    def duo_chat_panel_data(user, project, group)
      user_model_selection_enabled = ::Gitlab::Llm::TanukiBot.user_model_selection_enabled?(
        user: user,
        scope: project || group
      )
      chat_title = ::Ai::AmazonQ.enabled? ? s_('GitLab Duo Chat with Amazon Q') : s_('GitLab Duo Chat')
      is_agentic_available = ::Gitlab::Llm::TanukiBot.agentic_mode_available?(
        user: user, project: project, group: group
      )
      is_classic_chat_available = ::Gitlab::Llm::TanukiBot.classic_chat_available?(user: user)
      chat_disabled_reason = ::Gitlab::Llm::TanukiBot.chat_disabled_reason(
        user: user, container: project || group
      )
      credits_available = ::Gitlab::Llm::TanukiBot.credits_available?(
        user: user, project: project, group: group
      )
      default_namespace_selected = ::Gitlab::Llm::TanukiBot.default_duo_namespace_check_passes?(
        user: user
      )

      {
        user_id: user.to_global_id,
        project_id: (project.to_global_id if project&.persisted?),
        namespace_id: (group.to_global_id if group&.persisted?),
        root_namespace_id: ::Gitlab::Llm::TanukiBot.root_namespace_id(project || group),
        resource_id: ::Gitlab::Llm::TanukiBot.resource_id,
        metadata: ::Gitlab::DuoWorkflow::Client.metadata(user).to_json,
        user_model_selection_enabled: user_model_selection_enabled.to_s,
        agentic_available: is_agentic_available.to_s,
        classic_available: is_classic_chat_available.to_s,
        force_agentic_mode_for_core_duo_users: force_agentic_mode_for_core_duo_users?(user).to_s,
        agentic_unavailable_message: agentic_unavailable_message(user, project || group, is_agentic_available),
        chat_title: chat_title,
        chat_disabled_reason: chat_disabled_reason.to_s,
        credits_available: credits_available.to_s,
        default_namespace_selected: default_namespace_selected.to_s,
        preferences_path: profile_preferences_path(anchor: 'user_duo_default_namespace_id'),
        expanded: ('true' if ai_panel_expanded?),
        **subscription_status_data(group, project),
        explore_ai_catalog_path: explore_ai_catalog_path,
        auto_expand: should_auto_expand_duo_panel?(user).to_s
      }.merge(duo_chat_billing_attributes(user, project, group))
    end

    def subscription_status_data(group, project)
      if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
        saas_subscription_status(group, project)
      else
        self_managed_subscription_status
      end
    end

    def duo_chat_panel_empty_state_data(source: nil)
      path =
        if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
          if source.nil? || source.root_ancestor.is_a?(::Namespaces::UserNamespace)
            new_trial_path(glm_source: 'gitlab.com', glm_content: 'chat panel')
          elsif user_can_start_trial_in_source?(source)
            new_trial_path(namespace_id: source.root_ancestor.id, glm_source: 'gitlab.com', glm_content: 'chat panel')
          end
        else
          can?(current_user, :manage_subscription) ? self_managed_new_trial_url : nil
        end

      trial_duration =
        if path.nil?
          nil
        elsif ::Gitlab::Saas.feature_available?(:subscriptions_trials)
          GitlabSubscriptions::TrialDurationService.new.execute
        else
          DEFAULT_TRIAL_DURATION
        end

      {
        new_trial_path: path,
        trial_duration: trial_duration,
        namespace_type: source.is_a?(Group) ? source.type : nil
      }.compact
    end

    # rubocop:disable Layout/LineLength -- i18n
    def agentic_unavailable_message(user, container, is_agentic_available)
      return if is_agentic_available

      response = user.allowed_to_use(
        :agentic_chat,
        unit_primitive_name: :duo_chat,
        root_namespace: container&.root_ancestor
      )

      return unless response.allowed? && container.nil? && VALID_DUO_ADD_ONS.include?(response.enablement_type)

      preferences_url = '/-/profile/preferences#user_duo_default_namespace_id'
      preferences_link = link_to('', preferences_url)
      safe_format(
        s_('DuoChat|Duo Agentic Chat is not available at the moment in this page. To work with Duo Agentic Chat in pages outside the scope of a project please select a %{strong_start}Default GitLab Duo namespace%{strong_end} in your %{preferences_link_start}User Profile Preferences%{preferences_link_end}.'),
        tag_pair(content_tag(:strong, ''), :strong_start, :strong_end).merge(
          tag_pair(preferences_link, :preferences_link_start, :preferences_link_end)
        )
      )
    end
    # rubocop:enable Layout/LineLength

    def force_agentic_mode_for_core_duo_users?(user)
      return false unless ::Feature.enabled?(:no_duo_classic_for_duo_core_users, user)

      response = user.allowed_to_use(
        :agentic_chat,
        unit_primitive_name: :duo_chat
      )

      response.allowed? && response.enablement_type == "duo_core"
    end

    def should_auto_expand_duo_panel?(user)
      return false unless user

      !user.dismissed_callout?(feature_name: 'duo_panel_auto_expanded')
    end

    private

    def saas_subscription_status(group, project)
      namespace = (group || project)&.root_ancestor
      return { trial_active: nil, subscription_active: nil } unless namespace

      {
        trial_active: namespace.trial_active?.to_s,
        subscription_active: GitlabSubscriptions.active?(namespace).to_s
      }
    end

    def self_managed_subscription_status
      return { trial_active: nil, subscription_active: nil } unless License.current

      {
        trial_active: License.current.trial?.to_s,
        subscription_active: License.current.paid?.to_s
      }
    end

    def user_can_start_trial_in_source?(source)
      root = source.root_ancestor

      root.has_free_or_no_subscription? && can?(current_user, :admin_namespace, root)
    end

    def duo_chat_root_namespace(user, project, group)
      namespace = group || project&.group
      return namespace.root_ancestor if namespace

      ::Gitlab::Llm::TanukiBot.default_duo_namespace(user: user)&.root_ancestor
    end

    def duo_chat_billing_attributes(user, project, group)
      return duo_chat_billing_attributes_for_self_managed(user) unless saas?

      namespace = duo_chat_root_namespace(user, project, group)
      duo_chat_billing_attributes_for_saas(user, namespace)
    end

    def duo_chat_billing_attributes_for_self_managed(user)
      can_buy = can?(user, :admin_all_resources)
      is_trial = License.current&.trial?

      {
        is_trial: is_trial.to_s,
        can_buy_addon: can_buy.to_s,
        buy_addon_path: (duo_chat_buy_addon_path_for_self_managed(is_trial) if can_buy)
      }
    end

    def duo_chat_billing_attributes_for_saas(user, namespace)
      can_buy = !!(namespace && can?(user, :edit_billing, namespace))
      is_trial = !!namespace&.trial_active?

      {
        is_trial: is_trial.to_s,
        can_buy_addon: can_buy.to_s,
        buy_addon_path: (duo_chat_buy_addon_path_for_saas(namespace, is_trial) if can_buy)
      }
    end

    def duo_chat_buy_addon_path_for_self_managed(is_trial)
      return ::Gitlab::Routing.url_helpers.subscription_portal_url if is_trial

      admin_gitlab_credits_dashboard_index_path
    end

    def duo_chat_buy_addon_path_for_saas(namespace, is_trial)
      return ::Gitlab::Routing.url_helpers.subscription_portal_url if is_trial

      group_settings_gitlab_credits_dashboard_index_path(namespace)
    end

    def saas?
      ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
    end
  end
end
