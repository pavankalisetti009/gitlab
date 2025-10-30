<script>
import { GlCollapsibleListbox, GlEmptyState, GlSkeletonLoader, GlSprintf } from '@gitlab/ui';
import emptyJobPendingSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-job-pending-md.svg?url';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { getMessageData } from '../../../utils';
import ActivityLogs from '../../../components/common/activity_logs.vue';

export default {
  components: {
    ActivityLogs,
    GlCollapsibleListbox,
    GlEmptyState,
    GlSkeletonLoader,
    GlSprintf,
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
          // https://gitlab.com/gitlab-org/gitlab/-/issues/562418
          if (index === 0) {
            return true;
          }

          const messageData = getMessageData(item);
          return messageData && messageData.level && messageData.level > 0;
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
  emptyJobPendingSvg,
  filterOptions: [
    {
      value: 'verbose',
      text: s__('DuoAgentsPlatform|Full view'),
    },
    {
      value: 'important',
      text: s__('DuoAgentsPlatform|Concise view'),
    },
  ],
};
</script>
<template>
  <div class="gl-h-full">
    <div class="gl-border-b gl-flex gl-items-center gl-justify-end gl-bg-gray-10 gl-py-3 gl-pr-3">
      <gl-collapsible-listbox
        id="log-level"
        v-model="selectedFilter"
        :items="$options.filterOptions"
        :toggle-text="selectedFilterText"
        @select="onFilterChange"
      />
    </div>
    <div class="gl-relative gl-flex gl-flex-col gl-overflow-x-hidden gl-px-4 gl-pt-6">
      <div>
        <template v-if="isLoading">
          <gl-skeleton-loader class="gl-ml-4" />
          <gl-skeleton-loader class="gl-ml-4 gl-mt-4" />
        </template>
        <gl-empty-state
          v-else-if="!hasLogs"
          :title="s__('DuoAgentsPlatform|This session has no activity')"
          :svg-path="$options.emptyJobPendingSvg"
        >
          <template #description>
            <gl-sprintf
              :message="
                s__(
                  'DuoAgentsPlatform|To learn more about this session, view the %{boldStart}Details%{boldEnd} tab.',
                )
              "
            >
              <template #bold="{ content }">
                <strong>{{ content }}</strong>
              </template>
            </gl-sprintf>
          </template>
        </gl-empty-state>
        <activity-logs v-else :items="filteredLogs" />
      </div>
    </div>
  </div>
</template>
