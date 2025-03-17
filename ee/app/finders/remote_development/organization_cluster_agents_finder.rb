# frozen_string_literal: true

module RemoteDevelopment
  class OrganizationClusterAgentsFinder
    def self.execute(organization:, filter:, user:)
      return Clusters::Agent.none unless organization && user.can?(:read_organization_cluster_agent_mapping,
        organization)

      fetch_agents(filter, organization)
    end

    def self.fetch_agents(filter, organization)
      case filter
      when :unmapped
        # rubocop: disable CodeReuse/ActiveRecord -- activerecord is convenient for filtering for records
        Clusters::Agent.for_organizations([organization.id])
                       .left_joins(:organization_cluster_agent_mapping)
                       .where(organization_cluster_agent_mapping: { id: nil })
                       .select('"cluster_agents".*')
        # rubocop: enable CodeReuse/ActiveRecord
      when :directly_mapped
        organization.mapped_agents
      when :available
        organization.mapped_agents.with_remote_development_enabled
      else
        raise "Unsupported value for filter: #{filter}"
      end
    end
    private_class_method :fetch_agents
  end
end
