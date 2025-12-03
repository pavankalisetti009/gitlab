# frozen_string_literal: true

module Resolvers
  module Security
    class ScanProfilesResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type [Types::Security::ScanProfileType], null: false
      authorize :read_security_scan_profiles
      description 'Available security scan profiles.'

      argument :type, Types::Security::ScanProfileTypeEnum,
        required: false,
        description: 'Filter scan profiles by type.'

      alias_method :group, :object

      def resolve(type: nil)
        authorize!(object)

        existing_profiles = fetch_existing_profiles(type)
        applicable_defaults = fetch_applicable_defaults(type, existing_profiles)

        existing_profiles + applicable_defaults
      end

      private

      def root_ancestor
        @root_ancestor ||= group.root_ancestor
      end

      def fetch_existing_profiles(type)
        profiles = ::Security::ScanProfile.by_namespace(root_ancestor)
        filter_by_type(profiles, type)
      end

      def filter_by_type(profiles, type)
        return profiles if type.blank?

        profiles.by_type(type)
      end

      def fetch_applicable_defaults(type, existing_profiles)
        persisted_recommended_types = existing_profiles.select(&:gitlab_recommended).map(&:scan_type).uniq

        default_scan_profiles
          .select { |profile| matches_requested_type?(profile, type) }
          .reject { |profile| persisted_recommended_types.include?(profile.scan_type) }
      end

      def matches_requested_type?(profile, type)
        type.blank? || profile.scan_type == type
      end

      def default_scan_profiles
        ::Security::DefaultScanProfilesHelper.default_scan_profiles.tap do |scan_profiles|
          scan_profiles.each do |scan_profile|
            scan_profile.namespace_id = root_ancestor.id
          end
        end
      end
    end
  end
end
