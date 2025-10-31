<script>
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import getUserAgentFlows from '../../graphql/queries/get_user_agent_flow.query.graphql';
import DuoAgentsPlatformIndex from '../../pages/index/duo_agents_platform_index.vue';
import { DEFAULT_AGENT_PLATFORM_PAGINATION_VARIABLES } from '../../constants';

export default {
  components: { DuoAgentsPlatformIndex },
  data() {
    return {
      workflows: [],
      workflowsPageInfo: {},
      currentSort: 'UPDATED_DESC',
      hasInitialWorkflows: false,
      paginationVariables: { ...DEFAULT_AGENT_PLATFORM_PAGINATION_VARIABLES },
      filterVariables: {},
    };
  },
  apollo: {
    workflows: {
      query: getUserAgentFlows,
      pollInterval: 10000,
      variables() {
        return {
          ...this.paginationVariables,
          excludeTypes: ['chat'],
          sort: this.currentSort,
          ...this.filterVariables,
        };
      },
      update(data) {
        return data?.duoWorkflowWorkflows?.edges?.map((w) => w.node) || [];
      },
      result({ data }) {
        this.workflowsPageInfo = data?.duoWorkflowWorkflows?.pageInfo || {};

        const workflows = data?.duoWorkflowWorkflows?.edges?.map((w) => w.node) || [];
        if (workflows.length > 0) {
          this.hasInitialWorkflows = true;
        }
      },
      error(error) {
        createAlert({
          message: error.message || s__('DuoAgentsPlatform|Failed to fetch workflows'),
          captureError: true,
        });
      },
    },
  },
  computed: {
    isLoadingWorkflows() {
      return this.$apollo.queries.workflows.loading;
    },
  },
  methods: {
    handleQueryVariablesUpdate({ sort, pagination, filters }) {
      this.currentSort = sort;
      this.paginationVariables = pagination;
      this.filterVariables = filters;
    },
  },
};
</script>
<template>
  <duo-agents-platform-index
    :has-initial-workflows="hasInitialWorkflows"
    :initial-sort="currentSort"
    :is-loading-workflows="isLoadingWorkflows"
    :workflows="workflows"
    :workflows-page-info="workflowsPageInfo"
    class="gl-min-w-full"
    @query-variables-updated="handleQueryVariablesUpdate"
  />
</template>
