<script>
import { MessageMap } from '@gitlab/duo-ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';

export default {
  name: 'AgentFlowLogs',
  components: {
    MessageMap,
  },
  props: {
    isLoading: {
      type: Boolean,
      required: true,
    },
    agentFlowCheckpoint: {
      type: String,
      required: true,
    },
  },
  computed: {
    hasLogs() {
      return this.logs?.length > 0;
    },
    parsedCheckpoint() {
      if (!this.agentFlowCheckpoint) return null;

      try {
        return JSON.parse(this.agentFlowCheckpoint);
      } catch (err) {
        createAlert({
          message: s__('DuoAgentsPlatform|Could not display logs. Please try again.'),
        });
        return null;
      }
    },
    logs() {
      return this.parsedCheckpoint?.channel_values?.ui_chat_log || [];
    },
    messageMapCustomStyles() {
      return {
        '--duo-chat-message-color': 'var(--white, #ffffff)',
        '--duo-chat-message-heading-color': 'var(--white, #ffffff)',
        '--duo-chat-message-pre-color': 'var(--black, #000000)',
      };
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
        <message-map
          v-for="log in logs"
          :key="log.id"
          :message="log"
          :custom-styles="messageMapCustomStyles"
        />
      </template>
    </div>
  </div>
</template>
