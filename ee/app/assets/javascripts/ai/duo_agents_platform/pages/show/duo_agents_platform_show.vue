<script>
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { TYPENAME_AI_DUO_WORKFLOW } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { getDuoWorkflowEventsQuery } from '../../graphql/queries/get_duo_workflow_events.query.graphql';
import WorkflowDetails from './components/workflow_details.vue';

export default {
  name: 'DuoAgentsPlatformShow',
  components: { WorkflowDetails },
  data() {
    return {
      workflowEvents: [],
    };
  },
  apollo: {
    workflowEvents: {
      query: getDuoWorkflowEventsQuery,
      variables() {
        return {
          workflowId: convertToGraphQLId(TYPENAME_AI_DUO_WORKFLOW, this.$route.params.id),
        };
      },
      update(data) {
        return data?.duoWorkflowEvents?.nodes || [];
      },
      error(err) {
        createAlert(
          err?.message
            ? err.message
            : s__('DuoAgentsPlatform|Something went wrong while fetching Agent Flows'),
        );
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.workflowEvents.loading;
    },
    status() {
      return this.workflowEvents[0]?.workflowStatus || '';
    },
    workflowDefinition() {
      return this.workflowEvents[0]?.workflowDefinition || '';
    },
  },
};
</script>
<template>
  <workflow-details
    :is-loading="isLoading"
    :status="status"
    :workflow-definition="workflowDefinition"
    :workflow-events="workflowEvents"
  />
</template>
