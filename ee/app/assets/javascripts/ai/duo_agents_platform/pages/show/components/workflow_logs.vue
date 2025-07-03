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
      return this.workflowEvents?.length > 0
        ? this.workflowEvents[this.workflowEvents.length - 1]
        : null;
    },
    lastWorkflowCheckpoint() {
      return this.lastWorkflowEvent?.checkpoint;
    },
    logs() {
      try {
        if (this.lastWorkflowCheckpoint) {
          return JSON.parse(this.lastWorkflowCheckpoint)?.channel_values?.ui_chat_log;
        }

        return [];
      } catch (err) {
        createAlert(s__('DuoAgentsPlatform|Could not display logs. Please try again'));
        return [];
      }
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
<style scoped>
/* FIXME: This is temporary. Since we may well get rid of AgentMessage component,
* we want to fix the styling only here and not upstream in the component.
* https://gitlab.com/gitlab-org/gitlab/-/issues/553412
*/
.duo-chat-message .gl-markdown {
  color: var(--white, #ffffff);
}
</style>
