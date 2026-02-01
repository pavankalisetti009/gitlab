# frozen_string_literal: true

module Types
  module Members
    # Interface for roles that can be assigned to group or project members.
    module MemberRoleInterface
      include BaseInterface

      field :members_count,
        GraphQL::Types::Int,
        experiment: { milestone: '17.3' },
        description: 'Number of times the role has been directly assigned to a group or project member.'
    end
  end
end
