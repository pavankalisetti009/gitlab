<script>
import { GlEmptyState, GlKeysetPagination, GlLink, GlTableLite } from '@gitlab/ui';
import { s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { AGENTS_PLATFORM_SHOW_ROUTE } from '../../router/constants';

export default {
  name: 'AgentWorkflowsList',
  components: {
    GlEmptyState,
    GlKeysetPagination,
    GlLink,
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
  methods: {
    formatId(id) {
      return getIdFromGraphQLId(id);
    },
  },
  showRoute: AGENTS_PLATFORM_SHOW_ROUTE,
  workflowFields: [
    { key: 'goal', label: s__('DuoAgentsPlatform|Prompt') },
    { key: 'humanStatus', label: s__('DuoAgentsPlatform|Status') },
    { key: 'updatedAt', label: s__('DuoAgentsPlatform|Updated') },
    { key: 'id', label: 'ID' },
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
      <gl-table-lite :fields="$options.workflowFields" :items="workflows">
        <template #cell(goal)="{ item }">
          <gl-link :to="{ name: $options.showRoute, params: { id: formatId(item.id) } }">
            {{ item.goal }}
          </gl-link>
        </template>
        <template #cell(id)="{ item }">
          {{ formatId(item.id) }}
        </template>
      </gl-table-lite>
      <gl-keyset-pagination
        v-bind="workflowsPageInfo"
        class="gl-mt-5 gl-flex gl-justify-center"
        @prev="$emit('prev-page')"
        @next="$emit('next-page')"
      />
    </template>
  </div>
</template>
