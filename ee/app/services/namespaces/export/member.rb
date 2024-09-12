# frozen_string_literal: true

module Namespaces
  module Export
    class Member
      include ::ActiveModel::Attributes
      include ::ActiveModel::AttributeAssignment

      attribute :id, :integer
      attribute :name, :string
      attribute :username, :string
      attribute :email, :string
      attribute :membershipable_id, :integer
      attribute :membershipable_path, :string
      attribute :membershipable_type, :string
      attribute :role, :string
      attribute :membership_type, :string
      attribute :membership_source, :string
      attribute :access_granted, :string
      attribute :access_expired, :string
      attribute :access_level, :integer
      attribute :last_activity, :string

      def initialize(member, entity, parent_groups)
        super()

        map_attributes(member, entity, parent_groups)
      end

      def map_attributes(member, membershipable, parent_groups)
        membership_type = if member.source == membershipable
                            'direct'
                          elsif parent_groups.include?(member.source_id)
                            'inherited'
                          else
                            'shared'
                          end

        assign_attributes(
          id: member.id,
          name: member.user.name,
          username: member.user.username,
          email: member.user.email,
          membershipable_id: membershipable.id,
          membershipable_path: membershipable.full_path,
          membershipable_type: membershipable.class,
          access_level: member.access_level,
          role: member.present.access_level_for_export,
          membership_type: membership_type,
          membership_source: member.source.full_path,
          access_granted: member.created_at.to_fs(:csv),
          access_expired: member.expires_at,
          last_activity: member.last_activity_on
        )
      end
    end
  end
end
