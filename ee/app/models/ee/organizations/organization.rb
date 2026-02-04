# frozen_string_literal: true

module EE
  module Organizations
    module Organization
      extend ActiveSupport::Concern

      prepended do
        include ::Ai::FoundationalAgentsStatusable

        has_many :active_projects,
          -> { non_archived },
          class_name: 'Project',
          inverse_of: :organization
        has_many :add_on_purchases,
          class_name: 'GitlabSubscriptions::AddOnPurchase',
          inverse_of: :organization
        has_many :seat_assignments,
          class_name: 'GitlabSubscriptions::SeatAssignment',
          inverse_of: :organization
        has_many :user_add_on_assignments,
          class_name: 'GitlabSubscriptions::UserAddOnAssignment',
          inverse_of: :organization
        has_many :vulnerability_exports, class_name: 'Vulnerabilities::Export'
        has_many :sbom_sources, class_name: 'Sbom::Source'
        has_many :sbom_source_packages, class_name: 'Sbom::SourcePackage'
        has_many :sbom_components, class_name: 'Sbom::Component'
        has_many :sbom_component_versions, class_name: 'Sbom::ComponentVersion'
        has_many :organization_cluster_agent_mappings,
          class_name: 'RemoteDevelopment::OrganizationClusterAgentMapping',
          inverse_of: :organization
        has_many :mapped_agents, through: :organization_cluster_agent_mappings, source: :agent

        has_many :foundational_agents_status_records,
          class_name: 'Ai::OrganizationFoundationalAgentStatus',
          inverse_of: :organization

        def foundational_agents_default_enabled
          ::Ai::Setting.instance&.foundational_agents_default_enabled
        end
      end
    end
  end
end
