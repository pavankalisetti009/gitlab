<script>
import { GlLink } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { getTimeago } from '~/lib/utils/datetime/timeago_utility';
import { joinPaths } from '~/lib/utils/url_utility';
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
    showProjectInfo: {
      required: false,
      type: Boolean,
      default: false,
    },
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
    sessionUrl() {
      return this.item.project?.webUrl
        ? joinPaths(
            this.item.project.webUrl,
            '-/automate/agent-sessions',
            String(this.formatId(this.item.id)),
          )
        : null;
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
    handleItemSelected(event) {
      if (event.metaKey || event.ctrlKey) return;
      event.preventDefault();
      this.$router.push({
        name: this.$options.showRoute,
        params: { id: this.formatId(this.item.id) },
      });
    },
  },
  showRoute: AGENTS_PLATFORM_SHOW_ROUTE,
};
</script>
<template>
  <li class="gl-list-none">
    <gl-link
      :href="sessionUrl"
      class="gl-flex gl-flex-col gl-p-4"
      :class="linkHoverStyles"
      @click="handleItemSelected"
    >
      <div class="gl-flex gl-items-center gl-justify-between">
        <div class="gl-flex gl-items-center">
          <agent-status-icon :status="item.status" :human-status="formatStatus(item.humanStatus)" />
          <strong class="gl-pl-3 gl-text-strong">{{ formatName(item) }}</strong>
        </div>
        <div v-if="showProjectInfo && item.project" class="gl-text-subtle">
          {{ item.project.name }}
        </div>
      </div>

      <div class="gl-ml-7 gl-mt-0 gl-flex gl-items-center gl-gap-2 gl-text-subtle">
        <span>{{ formatStatus(item.humanStatus) }}</span>
        <span class="gl-text-subtle" aria-hidden="true">·</span>
        <span>{{ formatUpdatedAt(item.updatedAt) }}</span>
      </div>
    </gl-link>
  </li>
</template>
