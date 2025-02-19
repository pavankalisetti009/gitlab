# frozen_string_literal: true

module Projects
  module Filterable
    extend ActiveSupport::Concern

    private

    def by_saml_sso_session(projects)
      return projects unless params.fetch(:filter_expired_saml_session_projects, false)
      return projects unless current_user

      saml_providers_to_exclude = current_user.expired_sso_session_saml_providers_with_access_restricted

      return projects if saml_providers_to_exclude.blank?

      projects.by_not_in_root_id(
        saml_providers_to_exclude.map(&:group_id)
      )
    end
  end
end
