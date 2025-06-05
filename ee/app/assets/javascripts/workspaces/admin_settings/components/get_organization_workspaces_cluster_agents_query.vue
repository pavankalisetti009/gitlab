<script>
import { joinPaths } from '~/lib/utils/url_utility';
import { logError } from '~/lib/logger';

import organizationWorkspacesClusterAgentsQuery from '../graphql/queries/organization_workspaces_cluster_agents.query.graphql';
import mappedOrganizationClusterAgentsQuery from '../graphql/queries/organization_mapped_agents.query.graphql';
import { AVAILABILITY_OPTIONS } from '../constants';

export default {
  props: {
    organizationId: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      mappedAgentsLoaded: false,
      mappedAgents: null,
      agents: [],
      error: null,
      beforeCursor: null,
      afterCursor: null,
      hasNextPage: false,
      hasPreviousPage: false,
    };
  },
  apollo: {
    mappedAgents: {
      query: mappedOrganizationClusterAgentsQuery,
      variables() {
        return {
          organizationId: this.organizationId,
        };
      },
      skip() {
        return !this.organizationId;
      },
      error(error) {
        logError(error);
        this.error = error;
      },
      update(data) {
        this.error = null;

        const mappedAgentIds = data.organization.mappedAgents.nodes?.map((agent) => agent.id) || [];

        this.mappedAgentsLoaded = true;
        return new Set(mappedAgentIds);
      },
    },
    agents: {
      query: organizationWorkspacesClusterAgentsQuery,
      variables() {
        return {
          organizationId: this.organizationId,
        };
      },
      skip() {
        return !this.mappedAgentsLoaded;
      },
      error(error) {
        logError(error);
        this.error = error;
      },
      update(data) {
        this.error = null;

        const { pageInfo } = data.organization.organizationWorkspacesClusterAgents;

        this.hasNextPage = pageInfo.hasNextPage;
        this.hasPreviousPage = pageInfo.hasPreviousPage;
        this.beforeCursor = pageInfo.startCursor;
        this.afterCursor = pageInfo.endCursor;

        const agents = data.organization.organizationWorkspacesClusterAgents.nodes.map((agent) => ({
          name: agent.name,
          url: joinPaths(window.gon.gitlab_url, agent.webPath),
          group: agent.project?.group?.name || '',
          project: agent.project?.name || '',
          isConnected: Boolean(agent.connections?.nodes.length),
          workspacesEnabled: Boolean(agent.workspacesAgentConfig?.enabled),
          availability: this.mappedAgents.has(agent.id)
            ? AVAILABILITY_OPTIONS.AVAILABLE
            : AVAILABILITY_OPTIONS.BLOCKED,
        }));

        return agents;
      },
    },
  },
  methods: {
    nextPage() {
      this.$apollo.queries.agents.refetch({
        organizationId: this.organizationId,
        before: null,
        after: this.afterCursor,
      });
    },
    prevPage() {
      this.$apollo.queries.agents.refetch({
        organizationId: this.organizationId,
        before: this.beforeCursor,
        after: null,
      });
    },
    getPaginationData() {
      if (this.error) return null;

      return {
        show: this.hasNextPage || this.hasPreviousPage,
        hasPreviousPage: this.hasPreviousPage,
        hasNextPage: this.hasNextPage,
        nextPage: this.nextPage,
        prevPage: this.prevPage,
      };
    },
  },
  render() {
    return this.$scopedSlots.default?.({
      loading: this.$apollo.loading,
      error: this.error,
      agents: this.agents,
      pagination: this.getPaginationData(),
    });
  },
};
</script>
