<script>
import { GlLink } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { getTimeago } from '~/lib/utils/datetime/timeago_utility';
import { AGENTS_PLATFORM_SHOW_ROUTE } from '../../router/constants';
import { formatAgentFlowName, formatAgentStatus } from '../../utils';
import AgentStatusIcon from './agent_status_icon.vue';

export default {
  name: 'AgentFlowListItem',
  components: {
    GlLink,
    AgentStatusIcon,
  },
  props: {
    item: {
      required: true,
      type: Object,
    },
  },
  computed: {
    linkHoverStyles() {
      return [
        'hover:gl-bg-[--gl-action-neutral-background-color-hover]',
        'hover:gl-no-underline',
        'focus:gl-no-underline',
        'active:gl-no-underline',
        'focus:active:gl-no-underline',
      ];
    },
  },
  methods: {
    formatId(id) {
      return getIdFromGraphQLId(id);
    },
    formatName({ workflowDefinition, id }) {
      return formatAgentFlowName(workflowDefinition, this.formatId(id));
    },
    formatStatus(status) {
      return formatAgentStatus(status);
    },
    formatUpdatedAt(timestamp) {
      try {
        return getTimeago().format(timestamp);
      } catch {
        return timestamp || '';
      }
    },
  },
  showRoute: AGENTS_PLATFORM_SHOW_ROUTE,
};
</script>
<template>
  <li class="gl-list-none">
    <gl-link
      :to="{ name: $options.showRoute, params: { id: formatId(item.id) } }"
      class="gl-flex gl-flex-col gl-p-4"
      :class="linkHoverStyles"
    >
      <div>
        <agent-status-icon :status="item.status" :human-status="formatStatus(item.humanStatus)" />
        <strong class="gl-pl-1 gl-text-strong">{{ formatName(item) }}</strong>
      </div>

      <div class="gl-ml-7 gl-mt-1 gl-space-y-1 gl-text-subtle">
        <div>{{ formatUpdatedAt(item.updatedAt) }}</div>
        <div>{{ formatStatus(item.humanStatus) }}</div>
      </div>
    </gl-link>
  </li>
</template>
