<script>
import { AgentMessage as DuoAgentMessage, SystemMessage as DuoSystemMessage } from '@gitlab/duo-ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';

import { AGENT_MESSAGE_TYPE } from '../../../constants';

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
    hasLogs() {
      return this.logs?.length > 0;
    },
    lastWorkflowEvent() {
      return this.workflowEvents?.length > 0 ? this.workflowEvents[0] : null;
    },
    lastWorkflowCheckpoint() {
      if (!this.lastWorkflowEvent) return null;

      try {
        return JSON.parse(this.lastWorkflowEvent?.checkpoint);
      } catch (err) {
        createAlert({
          message: s__('DuoAgentsPlatform|Could not display logs. Please try again.'),
        });
        return null;
      }
    },
    logs() {
      return this.lastWorkflowCheckpoint?.channel_values?.ui_chat_log || [];
    },
  },
  methods: {
    messageComponent(log) {
      return log?.message_type === AGENT_MESSAGE_TYPE ? DuoAgentMessage : DuoSystemMessage;
    },
  },
};
</script>
<template>
  <div class="gl-w-2/3">
    <div class="gl-bg-gray-50 gl-p-3 gl-text-gray-500">{{ s__('DuoAgentsPlatform|Output') }}</div>
    <div class="gl-h-62 gl-overflow-y-auto gl-bg-gray-950 gl-p-6 gl-text-gray-100">
      <template v-if="isLoading">{{ s__('DuoAgentsPlatform|Fetching logs...') }}</template>
      <template v-else-if="!hasLogs">{{
        s__('DuoAgentsPlatform|No logs available yet.')
      }}</template>
      <template v-else>
        <component :is="messageComponent(log)" v-for="log in logs" :key="log.id" :message="log" />
      </template>
    </div>
  </div>
</template>
