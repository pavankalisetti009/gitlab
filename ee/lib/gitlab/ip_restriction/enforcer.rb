# frozen_string_literal: true

module Gitlab
  module IpRestriction
    class Enforcer
      def initialize(group)
        @group = group
      end

      def logger
        @logger ||= Gitlab::AuthLogger.build
      end

      def allows_current_ip?
        return true unless group&.licensed_feature_available?(:group_ip_restriction)

        return true unless current_ip_address

        allows_address?(current_ip_address)
      end

      private

      attr_reader :group

      def current_ip_address
        @current_ip_address ||= Gitlab::IpAddressState.current
      end

      def allows_address?(address)
        root_ancestor_ip_restrictions = group.root_ancestor_ip_restrictions

        return true unless root_ancestor_ip_restrictions.present?

        allowed = root_ancestor_ip_restrictions.any? { |ip_restriction| ip_restriction.allows_address?(address) }

        # Check against configured internal ranges
        allowed ||= globally_configured_ip_ranges.match?(address)

        details = access_details(allowed)
        log(details)
        audit(details)

        allowed
      end

      def log(details)
        logger.info(
          message: 'Attempting to access IP restricted group',
          **details
        )
      end

      def current_user
        username = ::Gitlab::ApplicationContext.current_context_attribute(:user)
        return unless username

        User.find_by_username(username)
      end

      def audit(details)
        ::Gitlab::Audit::Auditor.audit({
          name: 'ip_restricted_group_accessed',
          author: current_user || ::Gitlab::Audit::UnauthenticatedAuthor.new,
          scope: group,
          target: group,
          message: 'Attempting to access IP restricted group',
          additional_details: details
        })
      end

      def access_details(allowed)
        {
          allowed: allowed,
          ip_address: current_ip_address,
          group_full_path: group.full_path,
          global_allowlist_in_use: globally_configured_ip_ranges.present?
        }
      end

      def globally_configured_ip_ranges
        ::Gitlab::CIDR.new(Gitlab::CurrentSettings.globally_allowed_ips)
      end
    end
  end
end
