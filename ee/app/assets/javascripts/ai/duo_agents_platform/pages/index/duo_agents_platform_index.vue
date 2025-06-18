<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import WorkflowsList from '../../components/common/workflows_list.vue';
import { getWorkflows } from '../../graphql/queries/get_workflows.query.graphql';

export default {
  name: 'DuoAgentPlatformIndex',
  components: {
    GlLoadingIcon,
    WorkflowsList,
  },
  inject: ['emptyStateIllustrationPath', 'projectPath'],
  data() {
    return {
      workflows: [],
      workflowsPageInfo: {},
    };
  },
  apollo: {
    workflows: {
      query: getWorkflows,
      variables() {
        return {
          projectPath: this.projectPath,
          first: 20,
          before: null,
          last: null,
        };
      },
      update(data) {
        return data?.duoWorkflowWorkflows?.edges.map((w) => w.node) || [];
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
  methods: {
    handleNextPage() {
      this.$apollo.queries.workflows.refetch({
        projectPath: this.projectPath,
        before: null,
        after: this.workflowsPageInfo.endCursor,
        first: 20,
        last: null,
      });
    },
    handlePrevPage() {
      this.$apollo.queries.workflows.refetch({
        projectPath: this.projectPath,
        after: null,
        before: this.workflowsPageInfo.startCursor,
        first: null,
        last: 20,
      });
    },
  },
};
</script>
<template>
  <div class="gl-mt-10">
    <gl-loading-icon v-if="isLoadingWorkflows" size="lg" />
    <workflows-list
      v-else
      :empty-state-illustration-path="emptyStateIllustrationPath"
      :workflows="workflows"
      :workflows-page-info="workflowsPageInfo"
      @next-page="handleNextPage"
      @prev-page="handlePrevPage"
    />
  </div>
</template>
