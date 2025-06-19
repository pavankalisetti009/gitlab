<script>
import { s__ } from '~/locale';

export default {
  name: 'WorkflowLogs',
  props: {
    isLoading: {
      type: Boolean,
      required: true,
    },
    workflowEvents: {
      type: Array,
      required: true,
    },
  },
  computed: {
    lastWorkflowEvent() {
      return this.workflowEvents ? this.workflowEvents[this.workflowEvents.length - 1] : null;
    },
    lastWorkflowCheckpoint() {
      return this.lastWorkflowEvent?.checkpoint;
    },
    logs() {
      if (this.isLoading) {
        return s__('DuoAgentsPlatform|Fetching logs...');
      }

      return this.lastWorkflowCheckpoint || s__('DuoAgentsPlatform|No logs available yet.');
    },
  },
};
</script>
<template>
  <div class="gl-w-2/3">
    <div class="gl-bg-gray-50 gl-p-3 gl-text-gray-500">{{ s__('DuoAgentsPlatform|Output') }}</div>
    <div class="gl-h-62 gl-overflow-y-auto gl-bg-gray-950 gl-p-4 gl-text-gray-100">
      {{ logs }}
    </div>
  </div>
</template>
