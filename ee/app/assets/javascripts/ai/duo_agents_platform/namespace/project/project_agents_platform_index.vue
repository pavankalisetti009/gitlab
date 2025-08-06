<script>
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import getProjectAgentFlows from '../../graphql/queries/get_agent_flows.query.graphql';
import DuoAgentsPlatformIndex from '../../pages/index/duo_agents_platform_index.vue';

export default {
  components: { DuoAgentsPlatformIndex },
  inject: ['projectPath'],
  data() {
    return {
      workflows: [],
      workflowsPageInfo: {},
    };
  },
  apollo: {
    workflows: {
      query: getProjectAgentFlows,
      variables() {
        return {
          projectPath: this.projectPath,
          first: 20,
          before: null,
          last: null,
        };
      },
      update(data) {
        return data?.project?.duoWorkflowWorkflows?.edges?.map((w) => w.node) || [];
      },
      result({ data }) {
        this.workflowsPageInfo = data?.project?.duoWorkflowWorkflows?.pageInfo || {};
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
  />
</template>
