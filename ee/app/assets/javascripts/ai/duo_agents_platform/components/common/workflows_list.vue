<script>
import { GlEmptyState, GlKeysetPagination, GlTableLite } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'AgentWorkflowsList',
  components: {
    GlEmptyState,
    GlKeysetPagination,
    GlTableLite,
  },
  props: {
    emptyStateIllustrationPath: {
      required: true,
      type: String,
    },
    workflows: {
      required: true,
      type: Array,
    },
    workflowsPageInfo: {
      required: true,
      type: Object,
    },
  },
  computed: {
    hasWorkflows() {
      return this.workflows?.length > 0;
    },
  },
  workflowFields: [
    { key: 'id', label: 'ID' },
    { key: 'humanStatus', label: s__('DuoAgentsPlatform|Status') },
    { key: 'updatedAt', label: s__('DuoAgentsPlatform|Last updated') },
    { key: 'goal', label: s__('DuoAgentsPlatform|Prompt') },
  ],
};
</script>
<template>
  <div>
    <gl-empty-state
      v-if="!hasWorkflows"
      :title="s__('DuoAgentsPlatform|No Agent runs yet')"
      :description="s__('DuoAgentsPlatform|New Agent runs will appear here.')"
      :svg-path="emptyStateIllustrationPath"
    />
    <template v-else>
      <gl-table-lite :fields="$options.workflowFields" :items="workflows" />
      <gl-keyset-pagination
        v-bind="workflowsPageInfo"
        class="gl-mt-5 gl-flex gl-justify-center"
        @prev="$emit('prev-page')"
        @next="$emit('next-page')"
      />
    </template>
  </div>
</template>
