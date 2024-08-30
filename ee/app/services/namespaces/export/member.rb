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
      attribute :group_id, :integer
      attribute :group_path, :string
      attribute :role, :string
      attribute :membership_type, :string
      attribute :membership_source, :string
      attribute :access_granted, :string
      attribute :access_expired, :string
      attribute :access_level, :integer
      attribute :last_activity, :string

      def initialize(member, group, parent_groups)
        super()

        map_attributes(member, group, parent_groups)
      end

      def map_attributes(member, group, parent_groups)
        membership_type = if member.source == group
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
          group_id: group.id,
          group_path: group.full_path,
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
