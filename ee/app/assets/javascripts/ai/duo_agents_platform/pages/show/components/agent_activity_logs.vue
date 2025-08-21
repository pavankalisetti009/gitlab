<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { getMessageData } from '../../../utils';
import ActivityLogs from '../../../components/common/activity_logs.vue';

export default {
  components: {
    ActivityLogs,
    GlCollapsibleListbox,
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
  data() {
    return {
      selectedFilter: 'verbose',
    };
  },
  computed: {
    hasLogs() {
      return this.logs && this.logs.length > 0;
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
    filteredLogs() {
      if (this.selectedFilter === 'important') {
        return this.logs.filter((item, index) => {
          // Always include the first item (start message)
          if (index === 0) {
            return true;
          }

          const messageData = getMessageData(item);
          return messageData && messageData.level && messageData.level !== 0;
        });
      }
      return this.logs;
    },
    selectedFilterText() {
      const option = this.$options.filterOptions.find((o) => o.value === this.selectedFilter);
      return option ? option.text : '';
    },
  },
  methods: {
    onFilterChange(value) {
      this.selectedFilter = value;
    },
  },
  filterOptions: [
    {
      value: 'verbose',
      text: s__('DuoAgentsPlatform|Full'),
    },
    {
      value: 'important',
      text: s__('DuoAgentsPlatform|Concise'),
    },
  ],
};
</script>
<template>
  <div class="gl-h-full">
    <template v-if="isLoading">{{ s__('DuoAgentsPlatform|Fetching logs...') }}</template>
    <template v-else-if="!hasLogs">{{ s__('DuoAgentsPlatform|No logs available yet.') }}</template>
    <template v-else>
      <div
        class="gl-border-b gl-sticky gl-left-0 gl-top-0 gl-z-2 gl-flex gl-w-full gl-items-center gl-justify-end gl-bg-gray-10 gl-pr-3"
      >
        <label class="gl-m-0 gl-mr-4 gl-p-5" for="log-level">{{
          s__('DuoAgentsPlatform|Detail level')
        }}</label>
        <gl-collapsible-listbox
          id="log-level"
          v-model="selectedFilter"
          :items="$options.filterOptions"
          :toggle-text="selectedFilterText"
          @select="onFilterChange"
        />
      </div>
      <div class="gl-relative gl-flex gl-flex-col">
        <div class="gl-overflow-auto-y gl-h-[calc(100vh-21rem)] gl-pt-10">
          <activity-logs :items="filteredLogs" />
        </div>
      </div>
    </template>
  </div>
</template>
