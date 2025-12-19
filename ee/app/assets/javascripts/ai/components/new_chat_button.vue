<script>
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { GlAvatar, GlButton, GlTooltipDirective, GlCollapsibleListbox, GlIcon } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { __ } from '~/locale';
import {
  getCatalogAgentsQuery,
  getFoundationalAgentsQuery,
} from '../duo_agentic_chat/utils/apollo_utils';

export default {
  name: 'NewChatButton',
  components: {
    GlAvatar,
    GlIcon,
    GlButton,
    GlCollapsibleListbox,
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
        // NOTE any update here should also be made to ee/app/assets/javascripts/ai/duo_agentic_chat/components/duo_agentic_chat.vue
        update(data) {
          return (data?.aiCatalogConfiguredItems.nodes || []).map((node) => ({
            ...node.item,
            pinnedItemVersionId: node.pinnedItemVersion.id,
          }));
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
      searchTerm: '',
    };
  },
  computed: {
    ...mapState(['currentAgent']),
    agents() {
      return [...this.foundationalAgents, ...this.catalogAgents].map((agent) => ({
        ...agent,
        text: agent.name,
        value: agent.id,
      }));
    },
    selectedAgentValue() {
      const activeAgent = this.currentAgent || this.agents[0];
      return activeAgent?.id || null;
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
    dropdownItems() {
      const sanitizedSearchTerm = this.searchTerm.trim();

      return this.agents.filter(
        (agent) =>
          agent.text.toLowerCase().includes(sanitizedSearchTerm) ||
          agent.description.toLowerCase().includes(sanitizedSearchTerm),
      );
    },
  },
  methods: {
    ...mapActions(['setCurrentAgent']),
    handleStartNewChat(agentId) {
      this.setCurrentAgent(this.getSelectedAgent(agentId));

      this.$emit('new-chat');
    },
    getSelectedAgent(agentId) {
      return this.agents?.find((agent) => agent.id === agentId);
    },
    onSearch(text) {
      this.searchTerm = text.toLowerCase();
    },
    clearSearchInput() {
      this.searchTerm = '';

      // FIXME: Expose a way for consumers of GlCollapsibleListbox to
      // clear its internal search input. https://gitlab.com/gitlab-org/gitlab/-/issues/583205
      this.$refs.customAgentSelector.$refs.searchBox?.clearInput();
    },
    onSelect(selectedArr) {
      let selected = this.selectedAgentValue;
      if (selectedArr.length) {
        // considering we're in the multiselect mode, we need only the new agent
        [selected] = selectedArr.filter((id) => id !== this.selectedAgentValue);
      }
      this.handleStartNewChat(selected);
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    v-if="hasManyAgents"
    ref="customAgentSelector"
    :title="$options.i18n.addNewChat"
    :toggle-text="$options.i18n.addNewChat"
    :aria-label="$options.i18n.addNewChat"
    :header-text="__('Choose an agent')"
    :selected="selectedAgentValue"
    :items="dropdownItems"
    data-testid="add-new-agent-toggle"
    category="primary"
    variant="default"
    size="small"
    icon="pencil-square"
    class="ai-nav-icon-agents"
    searchable
    fluid-width
    text-sr-only
    no-caret
    multiple
    @select="onSelect"
    @hidden="clearSearchInput"
    @search="onSearch"
  >
    <template #list-item="{ item }">
      <span class="gl-flex">
        <gl-avatar :size="24" :entity-name="item.name" shape="circle" />
        <span class="gl-flex gl-w-31 gl-flex-col gl-pl-3">
          <span class="gl-mb-1 gl-inline-block gl-break-all gl-font-bold">
            {{ item.name }}
            <gl-icon
              v-if="item.foundational"
              v-gl-tooltip
              name="tanuki-verified"
              variant="subtle"
              :title="$options.i18n.chatVerifiedAgent"
            />
          </span>
          <span class="gl-line-clamp-3 gl-text-sm gl-text-subtle">
            {{ item.description }}
          </span>
        </span>
      </span>
    </template>
  </gl-collapsible-listbox>
  <gl-button
    v-else
    v-gl-tooltip.left
    icon="pencil-square"
    size="small"
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
