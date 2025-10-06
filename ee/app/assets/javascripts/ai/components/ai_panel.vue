<script>
import { GlBreakpointInstance } from '@gitlab/ui/src/utils';
import { __ } from '~/locale';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import AgentSessionsRoot from '~/vue_shared/spa/components/spa_root.vue';
import { AGENTS_PLATFORM_SHOW_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';
import { formatAgentFlowName } from 'ee/ai/duo_agents_platform/utils';
import DuoAgenticChat from 'ee/ai/duo_agentic_chat/components/duo_agentic_chat.vue';
import AiContentContainer from './content_container.vue';
import NavigationRail from './navigation_rail.vue';

export default {
  PANEL_EXPANDED_STORAGE_KEY: 'ai-panel-expanded',
  ACTIVE_TAB_KEY: 'ai-panel-active-tab',
  components: {
    AiContentContainer,
    NavigationRail,
    LocalStorageSync,
  },
  inject: {
    isAgenticAvailable: {
      default: false,
    },
    chatTitle: {
      default: null,
    },
  },
  props: {
    userId: {
      type: String,
      required: false,
      default: null,
    },
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
    rootNamespaceId: {
      type: String,
      required: false,
      default: null,
    },
    resourceId: {
      type: String,
      required: false,
      default: null,
    },
    metadata: {
      type: String,
      required: false,
      default: null,
    },
    userModelSelectionEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      isExpanded: true,
      activeTab: localStorage.getItem(this.$options.ACTIVE_TAB_KEY) || null,
      isDesktop: GlBreakpointInstance.isDesktop(),
    };
  },
  computed: {
    availableChat() {
      return this.isAgenticAvailable ? DuoAgenticChat : __('Classic Chat Placeholder');
    },
    getChatTitle() {
      return this.chatTitle ? this.chatTitle : __('GitLab Duo Agentic Chat');
    },
    currentTabComponent() {
      switch (this.activeTab) {
        case 'chat':
          return {
            title: this.getChatTitle,
            component: this.availableChat,
            props: { mode: 'active', isAgenticAvailable: this.isAgenticAvailable },
          };
        case 'new':
          return {
            title: __('New Chat'),
            component: this.availableChat,
            props: { mode: 'new', isAgenticAvailable: this.isAgenticAvailable },
          };
        case 'history':
          return {
            title: __('History'),
            component: this.availableChat,
            props: { mode: 'history', isAgenticAvailable: this.isAgenticAvailable },
          };
        case 'suggestions':
          return {
            title: __('Suggestions'),
            component: __('Suggestions content placeholder'),
          };
        case 'sessions':
          return {
            title: this.sessionTitle,
            component: AgentSessionsRoot,
            initialRoute: '/agent-sessions',
          };
        default:
          return null;
      }
    },
    sessionTitle() {
      // For now, we don't know the flow type here to format the title.
      return this.$route.name === AGENTS_PLATFORM_SHOW_ROUTE
        ? formatAgentFlowName(null, this.$route.params.id)
        : __('Sessions');
    },
    showBackButton() {
      return (
        this.currentTabComponent?.initialRoute &&
        this.currentTabComponent.initialRoute !== this.$route.path
      );
    },
  },
  mounted() {
    window.addEventListener('resize', this.handleWindowResize);
  },
  beforeDestroy() {
    window.removeEventListener('resize', this.handleWindowResize);
  },
  methods: {
    toggleAIPanel(val) {
      this.isExpanded = val;
      if (!val) this.activeTab = null;
    },
    handleGoBack() {
      if (this.currentTabComponent.initialRoute) {
        this.$router.push(this.currentTabComponent.initialRoute);
      }
    },
    handleTabToggle(tab) {
      if (tab === this.activeTab) {
        // Collapse and clear active tab
        this.toggleAIPanel(false);
        this.activeTab = null;
        localStorage.removeItem(this.$options.ACTIVE_TAB_KEY);
        return;
      }
      this.activeTab = tab;
      localStorage.setItem(this.$options.ACTIVE_TAB_KEY, tab);
      if (!this.isExpanded) {
        this.toggleAIPanel(true);
      }

      // Navigate to the initial route if the tab has one (e.g., sessions)
      this.$nextTick(() => {
        if (this.currentTabComponent?.initialRoute) {
          this.$router.push(this.currentTabComponent.initialRoute);
        }
      });
    },
    onSwitchToActiveTab(tab) {
      this.activeTab = tab;
      localStorage.setItem(this.$options.ACTIVE_TAB_KEY, tab);
    },
    handleWindowResize() {
      const currentIsDesktop = GlBreakpointInstance.isDesktop();

      // This check ensures that the panel is collapsed only when resizing
      // from desktop to mobile/tablet, not the other way around
      if (this.isDesktop && !currentIsDesktop) {
        this.isExpanded = false;
        this.activeTab = null;
      }

      this.isDesktop = currentIsDesktop;
    },
  },
};
</script>
<template>
  <div class="gl-flex gl-h-full gl-gap-3">
    <local-storage-sync
      :value="isExpanded"
      :storage-key="$options.PANEL_EXPANDED_STORAGE_KEY"
      @input="toggleAIPanel($event)"
    />
    <ai-content-container
      v-if="activeTab"
      :user-id="userId"
      :active-tab="currentTabComponent"
      :is-expanded="isExpanded"
      :show-back-button="showBackButton"
      :project-id="projectId"
      :namespace-id="namespaceId"
      :root-namespace-id="rootNamespaceId"
      :resource-id="resourceId"
      :metadata="metadata"
      :user-model-selection-enabled="userModelSelectionEnabled"
      @closePanel="toggleAIPanel"
      @go-back="handleGoBack()"
      @switch-to-active-tab="onSwitchToActiveTab"
    />
    <navigation-rail
      :is-expanded="isExpanded"
      :active-tab="activeTab"
      @handleTabToggle="handleTabToggle"
    />
  </div>
</template>
