# frozen_string_literal: true

module EE
  module Resolvers
    module Projects
      module UserContributedProjectsResolver
        extend ::Gitlab::Utils::Override

        override :finder_params
        def finder_params(args)
          super.merge(filter_expired_saml_session_projects: true)
        end
      end
    end
  end
end
