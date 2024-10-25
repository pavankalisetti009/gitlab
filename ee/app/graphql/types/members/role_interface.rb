# frozen_string_literal: true

module Types
  module Members
    module RoleInterface
      include BaseInterface

      field :name,
        GraphQL::Types::String,
        description: 'Role name.'

      field :members_count,
        GraphQL::Types::Int,
        alpha: { milestone: '17.3' },
        description: 'Number of times the role has been directly assigned to a group or project member.'

      field :users_count,
        GraphQL::Types::Int,
        alpha: { milestone: '17.5' },
        description: 'Number of users who have been directly assigned the role in at least one group or project.'

      field :details_path,
        GraphQL::Types::String,
        alpha: { milestone: '17.4' },
        description: 'URL path to the role details webpage.'
    end
  end
end
