<script>
import { GlButton, GlTooltipDirective, GlDisclosureDropdown, GlIcon } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { __ } from '~/locale';
import {
  getCatalogAgentsQuery,
  getFoundationalAgentsQuery,
} from '../duo_agentic_chat/utils/apollo_utils';

export default {
  name: 'NewChatButton',
  components: {
    GlIcon,
    GlButton,
    GlDisclosureDropdown,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  i18n: {
    addNewChat: __('Add new chat'),
    chatVerifiedAgent: __('Created and maintained by GitLab'),
    newLabel: __('New GitLab Duo Chat'),
  },
  props: {
    projectId: {
      type: String,
      required: false,
      default: null,
    },
    namespaceId: {
      type: String,
      required: false,
      default: null,
    },
    activeTab: {
      type: String,
      required: false,
      default: null,
    },
    isExpanded: {
      type: Boolean,
      required: false,
      default: true,
    },
    isChatDisabled: {
      type: Boolean,
      required: false,
      default: true,
    },
    chatDisabledTooltip: {
      type: String,
      required: false,
      default: null,
    },
    isAgentSelectEnabled: {
      type: Boolean,
      required: true,
    },
  },
  apollo: {
    catalogAgents() {
      return {
        ...getCatalogAgentsQuery(this.catalogAgentsVariables),
        skip() {
          return !this.isAgentSelectEnabled;
        },
        error: (error) => {
          this.$emit('newChatError', error);
          Sentry.captureException(error);
        },
      };
    },
    foundationalAgents() {
      return {
        ...getFoundationalAgentsQuery(this.foundationalAgentsVariables),
        skip() {
          return !this.isAgentSelectEnabled;
        },
        error: (error) => {
          this.$emit('newChatError', error);
          Sentry.captureException(error);
        },
      };
    },
  },
  data() {
    return {
      catalogAgents: [],
      foundationalAgents: [],
    };
  },
  computed: {
    agents() {
      return [...this.foundationalAgents, ...this.catalogAgents].map((agent) => ({
        ...agent,
        text: agent.name,
      }));
    },
    catalogAgentsVariables() {
      return this.projectId ? { projectId: this.projectId } : { groupId: this.namespaceId };
    },
    foundationalAgentsVariables() {
      return {
        projectId: this.projectId,
        namespaceId: this.namespaceId,
      };
    },
    hasManyAgents() {
      return this.isAgentSelectEnabled && this.agents.length > 1;
    },
  },
  methods: {
    handleStartNewChat(agent) {
      this.$emit('new-chat', agent);
    },
  },
};
</script>

<template>
  <gl-disclosure-dropdown
    v-if="hasManyAgents"
    :title="$options.i18n.addNewChat"
    :toggle-text="$options.i18n.addNewChat"
    :items="agents"
    data-testid="add-new-agent-toggle"
    category="primary"
    variant="default"
    icon="pencil-square"
    class="ai-nav-icon-agents"
    text-sr-only
    :aria-label="$options.i18n.addNewChat"
    no-caret
    @action="handleStartNewChat"
  >
    <template #list-item="{ item }">
      <span class="gl-flex gl-flex-col">
        <span class="gl-mb-1 gl-inline-block gl-break-all gl-font-semibold">
          {{ item.name }}
          <gl-icon
            v-if="item.foundational"
            v-gl-tooltip
            name="tanuki-verified"
            variant="subtle"
            :title="$options.i18n.chatVerifiedAgent"
          />
        </span>
        <span
          class="gl-overflow-hidden gl-text-ellipsis gl-whitespace-nowrap gl-text-sm gl-text-subtle"
        >
          {{ item.description }}
        </span>
      </span>
    </template>
  </gl-disclosure-dropdown>
  <gl-button
    v-else
    v-gl-tooltip.left
    icon="pencil-square"
    class="!gl-rounded-full"
    :class="[
      'ai-nav-icon',
      { 'ai-nav-icon-active': activeTab === 'new', 'gl-opacity-5': isChatDisabled },
    ]"
    category="primary"
    variant="default"
    :aria-selected="activeTab === 'new'"
    :aria-expanded="isExpanded"
    :aria-label="$options.i18n.newLabel"
    :title="isChatDisabled ? chatDisabledTooltip : $options.i18n.newLabel"
    role="tab"
    :aria-disabled="isChatDisabled"
    data-testid="ai-new-toggle"
    @mouseout="$emit('hideTooltips')"
    @click="$emit('new-chat')"
  />
</template>
