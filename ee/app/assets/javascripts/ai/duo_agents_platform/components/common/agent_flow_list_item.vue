<script>
import { GlLink } from '@gitlab/ui';
import { last } from 'lodash';
import { __ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { getTimeago } from '~/lib/utils/datetime/timeago_utility';
import { joinPaths } from '~/lib/utils/url_utility';
import { AGENTS_PLATFORM_SHOW_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';
import { formatAgentStatus, formatAgentDefinition } from 'ee/ai/duo_agents_platform/utils';
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
    lastMessage() {
      return last(this.item.latestCheckpoint?.duoMessages)?.content;
    },
    lastMessageOrStatus() {
      return this.lastMessage ? this.lastMessage : __('Last updated');
    },
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
    formatProjectFlowTitle({ project, workflowDefinition }) {
      return `${this.showProjectInfo && project ? `${project.name} / ` : ''}${formatAgentDefinition(workflowDefinition)}`;
    },
    formatIdTitle({ id }) {
      return `#${this.formatId(id)}`;
    },
    formatStatus(status) {
      return formatAgentStatus(status);
    },
    formatCreatedAt({ createdAt }) {
      return `${__('Created')} ${this.formatTimestamp(createdAt)}`;
    },
    formatTimestamp(timestamp) {
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
        <div class="gl-flex gl-items-center" data-testid="item-title">
          <agent-status-icon :status="item.status" :human-status="formatStatus(item.humanStatus)" />
          <strong class="gl-pl-3 gl-text-strong">{{ formatProjectFlowTitle(item) }}</strong>
          <span class="gl-pl-1 gl-text-subtle" aria-hidden="true">-</span>
          <span class="gl-pl-1 gl-text-subtle">{{ formatIdTitle(item) }}</span>
        </div>
      </div>

      <div
        class="gl-ml-7 gl-mt-0 gl-flex gl-items-center gl-gap-2 gl-text-subtle"
        data-testid="item-created-date"
      >
        <span>{{ formatCreatedAt(item) }}</span>
      </div>
      <div class="gl-ml-7 gl-mt-0 gl-flex gl-items-center gl-gap-2 gl-text-subtle">
        <span
          :class="{ 'gl-max-w-80 gl-truncate': lastMessage }"
          data-testid="item-last-updated-message"
          >{{ lastMessageOrStatus }}</span
        >
        <span :class="{ 'gl-min-w-20': lastMessage }" data-testid="item-updated-date">{{
          formatTimestamp(item.updatedAt)
        }}</span>
      </div>
    </gl-link>
  </li>
</template>
