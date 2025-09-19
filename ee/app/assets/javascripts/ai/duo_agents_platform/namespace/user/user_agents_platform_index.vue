<script>
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import getUserAgentFlows from '../../graphql/queries/get_user_agent_flow.query.graphql';
import DuoAgentsPlatformIndex from '../../pages/index/duo_agents_platform_index.vue';

export default {
  components: { DuoAgentsPlatformIndex },
  data() {
    return {
      workflows: [],
      workflowsPageInfo: {},
    };
  },
  apollo: {
    workflows: {
      query: getUserAgentFlows,
      pollInterval: 10000,
      variables() {
        return {
          first: 20,
          before: null,
          last: null,
        };
      },
      update(data) {
        return data?.duoWorkflowWorkflows?.edges?.map((w) => w.node) || [];
      },
      result({ data }) {
        this.workflowsPageInfo = data?.duoWorkflowWorkflows?.pageInfo || {};
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
};
</script>
<template>
  <duo-agents-platform-index
    :is-loading-workflows="isLoadingWorkflows"
    :workflows="workflows"
    :workflows-page-info="workflowsPageInfo"
    :workflow-query="$apollo.queries.workflows"
    class="gl-min-w-full"
  />
</template>
