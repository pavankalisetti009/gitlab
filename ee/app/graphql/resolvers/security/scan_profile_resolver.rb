# frozen_string_literal: true

module Resolvers
  module Security
    class ScanProfileResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type Types::Security::ScanProfileType, null: true
      authorize :read_security_scan_profiles
      description 'Resolves security scan profiles.'

      argument :id, ::Types::GlobalIDType[::Security::ScanProfile],
        required: true,
        description: 'Global ID of the security scan profile.'

      def resolve(id:)
        model_id = id.model_id
        return find_default_profile(model_id) if model_id && Enums::Security.scan_profile_types.key?(model_id.to_sym)

        authorized_find!(id: id)
      end

      private

      def find_default_profile(model_id)
        profile = ::Security::DefaultScanProfilesHelper.default_scan_profiles.find do |profile|
          profile.scan_type == model_id
        end

        raise_resource_not_available_error! unless profile
        profile
      end
    end
  end
end
