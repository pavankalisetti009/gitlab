# frozen_string_literal: true

module Ai
  module UserAuthorizable
    extend ActiveSupport::Concern

    GROUP_WITH_AI_ENABLED_CACHE_PERIOD = 1.hour
    GROUP_WITH_AI_ENABLED_CACHE_KEY = 'group_with_ai_enabled'
    GROUP_WITH_GA_AI_ENABLED_CACHE_KEY = 'group_with_ga_ai_enabled'

    GROUP_WITH_AI_CHAT_ENABLED_CACHE_PERIOD = 1.hour
    GROUP_WITH_AI_CHAT_ENABLED_CACHE_KEY = 'group_with_ai_chat_enabled'
    GROUP_IDS_WITH_AI_CHAT_ENABLED_CACHE_KEY = 'group_ids_with_ai_chat_enabled'

    GROUP_REQUIRES_LICENSED_SEAT_FOR_CHAT_CACHE_PERIOD = 10.minutes
    GROUP_REQUIRES_LICENSED_SEAT_FOR_CHAT_CACHE_KEY = 'group_requires_licensed_seat_for_chat'

    DUO_PRO_ADD_ON_CACHE_KEY = 'user-%{user_id}-code-suggestions-add-on-cache'

    included do
      def duo_pro_add_on_available_namespace_ids
        cache_key = format(DUO_PRO_ADD_ON_CACHE_KEY, user_id: id)

        Rails.cache.fetch(cache_key, expires_in: 1.hour) do
          GitlabSubscriptions::UserAddOnAssignment.by_user(self).for_active_gitlab_duo_pro_purchase
            .pluck('subscription_add_on_purchases.namespace_id') # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- limited to a single user's purchases
        end
      end

      def duo_pro_cache_key_formatted
        format(User::DUO_PRO_ADD_ON_CACHE_KEY, user_id: id)
      end

      def eligible_for_self_managed_gitlab_duo_pro?
        return false if gitlab_com_subscription?

        active? && !bot? && !ghost?
      end

      # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- limited to a single user's groups
      def billable_gitlab_duo_pro_root_group_ids
        return unless gitlab_com_subscription?

        group_ids_from_project_authorizaton = Project.where(id: project_authorizations.non_guests.select(:project_id))
          .pluck(:namespace_id)
        group_ids_from_memberships = GroupMember.with_user(self).active.non_guests.pluck(:source_id)
        group_ids_from_linked_groups = GroupGroupLink.non_guests.where(shared_with_group_id: group_ids_from_memberships)
          .pluck(:shared_group_id)

        Group.where(
          id: group_ids_from_project_authorizaton | group_ids_from_memberships | group_ids_from_linked_groups
        ).pluck(Arel.sql('traversal_ids[1]')).uniq
      end
      # rubocop: enable Database/AvoidUsingPluckWithoutLimit

      def any_group_with_ai_available?
        Rails.cache.fetch(['users', id, GROUP_WITH_AI_ENABLED_CACHE_KEY],
          expires_in: GROUP_WITH_AI_ENABLED_CACHE_PERIOD) do
          member_namespaces.namespace_settings_with_ai_features_enabled.with_ai_supported_plan.any?
        end
      end

      def any_group_with_ga_ai_available?(service_name)
        Rails.cache.fetch(['users', id, GROUP_WITH_GA_AI_ENABLED_CACHE_KEY],
          expires_in: GROUP_WITH_AI_ENABLED_CACHE_PERIOD) do
          groups = member_namespaces.with_ai_supported_plan
          groups_that_require_licensed_seat = groups.select do |group|
            ::Feature.enabled?(:duo_chat_requires_licensed_seat, group)
          end

          if groups.any? && groups_that_require_licensed_seat.any?
            ::CloudConnector::AvailableServices.find_by_name(service_name).allowed_for?(self)
          else
            groups.any?
          end
        end
      end

      def ai_chat_enabled_namespace_ids
        Rails.cache.fetch(['users', id, GROUP_IDS_WITH_AI_CHAT_ENABLED_CACHE_KEY],
          expires_in: GROUP_WITH_AI_CHAT_ENABLED_CACHE_PERIOD) do
          groups = member_namespaces.with_ai_supported_plan(:ai_chat)
          groups.pluck(Arel.sql('DISTINCT traversal_ids[1]')) # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- limited to a single user's groups
        end
      end

      def any_group_with_ai_chat_available?
        Rails.cache.fetch(['users', id, GROUP_WITH_AI_CHAT_ENABLED_CACHE_KEY],
          expires_in: GROUP_WITH_AI_CHAT_ENABLED_CACHE_PERIOD) do
          groups = member_namespaces.with_ai_supported_plan(:ai_chat)
          groups_that_require_licensed_seat_for_chat = groups.select do |group|
            ::Feature.enabled?(:duo_chat_requires_licensed_seat, group)
          end

          if groups.any? && groups_that_require_licensed_seat_for_chat.any?
            ::CloudConnector::AvailableServices.find_by_name(:duo_chat).allowed_for?(self)
          else
            groups.any?
          end
        end
      end

      def belongs_to_group_requires_licensed_seat_for_chat?
        Rails.cache.fetch(['users', id, GROUP_REQUIRES_LICENSED_SEAT_FOR_CHAT_CACHE_KEY],
          expires_in: GROUP_REQUIRES_LICENSED_SEAT_FOR_CHAT_CACHE_PERIOD) do
          group_ids = ::Feature.group_ids_for(:duo_chat_requires_licensed_seat)
          member_namespaces.by_root_id(group_ids).any?
        end
      end
    end

    class_methods do
      def clear_group_with_ai_available_cache(ids)
        cache_keys_ai_features = Array.wrap(ids).map { |id| ["users", id, GROUP_WITH_AI_ENABLED_CACHE_KEY] }
        cache_keys_ga_ai_features = Array.wrap(ids).map { |id| ["users", id, GROUP_WITH_GA_AI_ENABLED_CACHE_KEY] }
        cache_keys_ai_chat = Array.wrap(ids).map { |id| ["users", id, GROUP_WITH_AI_CHAT_ENABLED_CACHE_KEY] }
        cache_keys_ai_chat_group_ids = Array.wrap(ids).map do |id|
          ["users", id, GROUP_IDS_WITH_AI_CHAT_ENABLED_CACHE_KEY]
        end
        cache_keys_requires_licensed_seat = Array.wrap(ids).map do |id|
          ["users", id, GROUP_REQUIRES_LICENSED_SEAT_FOR_CHAT_CACHE_KEY]
        end

        cache_keys = cache_keys_ai_features + cache_keys_ga_ai_features + cache_keys_ai_chat +
          cache_keys_ai_chat_group_ids + cache_keys_requires_licensed_seat
        ::Gitlab::Instrumentation::RedisClusterValidator.allow_cross_slot_commands do
          Rails.cache.delete_multi(cache_keys)
        end
      end
    end
  end
end
