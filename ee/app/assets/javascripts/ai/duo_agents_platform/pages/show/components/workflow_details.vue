<script>
import WorkflowHeader from './workflow_header.vue';
import WorkflowInfo from './workflow_info.vue';
import WorkflowLogs from './workflow_logs.vue';

export default {
  name: 'WorkflowDetails',
  components: {
    WorkflowHeader,
    WorkflowInfo,
    WorkflowLogs,
  },
  props: {
    isLoading: {
      required: true,
      type: Boolean,
    },
    status: {
      required: true,
      type: String,
    },
    workflowDefinition: {
      required: true,
      type: String,
    },
    workflowEvents: {
      type: Array,
      required: true,
    },
  },
};
</script>
<template>
  <div>
    <workflow-header :is-loading="isLoading" :workflow-definition="workflowDefinition" />
    <div class="gl-mt-6 gl-flex">
      <workflow-logs :is-loading="isLoading" :workflow-events="workflowEvents" />
      <workflow-info
        :is-loading="isLoading"
        :status="status"
        :workflow-definition="workflowDefinition"
      />
    </div>
  </div>
</template>
