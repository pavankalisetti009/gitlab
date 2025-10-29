<script>
import { GlBreakpointInstance } from '@gitlab/ui/src/utils'; // eslint-disable-line no-restricted-syntax -- GlBreakpointInstance is used intentionally here. In this case we must obtain viewport breakpoints
import { __ } from '~/locale';
import AgentSessionsRoot from '~/vue_shared/spa/components/spa_root.vue';
import { AGENTS_PLATFORM_SHOW_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';
import { formatAgentFlowName } from 'ee/ai/duo_agents_platform/utils';
import { CHAT_MODES } from 'ee/ai/tanuki_bot/constants';
import Cookies from '~/lib/utils/cookies';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import AiContentContainer from './content_container.vue';
import NavigationRail from './navigation_rail.vue';

const ACTIVE_TAB_KEY = 'ai_panel_active_tab';

export default {
  name: 'AiPanel',
  components: {
    AiContentContainer,
    NavigationRail,
  },
  inject: ['chatConfiguration'],
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
    // Initialize global state from cookie if not already set
    if (duoChatGlobalState.activeTab === null) {
      duoChatGlobalState.activeTab = Cookies.get(ACTIVE_TAB_KEY) || undefined;
    }

    return {
      isDesktop: GlBreakpointInstance.isDesktop(),
      duoChatGlobalState,
    };
  },
  computed: {
    activeTab() {
      return this.duoChatGlobalState.activeTab;
    },
    isAgenticMode() {
      return this.duoChatGlobalState.chatMode === CHAT_MODES.AGENTIC;
    },
    currentChatComponent() {
      return this.isAgenticMode
        ? this.chatConfiguration.agenticComponent
        : this.chatConfiguration.classicComponent;
    },
    currentChatTitle() {
      return this.isAgenticMode
        ? this.chatConfiguration.agenticTitle
        : this.chatConfiguration.classicTitle;
    },
    currentTabComponent() {
      switch (this.activeTab) {
        case 'chat':
          return {
            title: this.currentChatTitle,
            component: this.currentChatComponent,
            props: { mode: 'active', ...this.chatConfiguration.defaultProps },
          };
        case 'new':
          return {
            title: __('New Chat'),
            component: this.currentChatComponent,
            props: { mode: 'new', ...this.chatConfiguration.defaultProps },
          };
        case 'history':
          return {
            title: __('History'),
            component: this.currentChatComponent,
            props: { mode: 'history', ...this.chatConfiguration.defaultProps },
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
    window.addEventListener('focus', this.handleWindowFocus);
  },
  beforeDestroy() {
    window.removeEventListener('resize', this.handleWindowResize);
    window.removeEventListener('focus', this.handleWindowFocus);
  },
  methods: {
    handleGoBack() {
      if (this.currentTabComponent.initialRoute) {
        this.$router.push(this.currentTabComponent.initialRoute);
      }
    },
    setActiveTab(value) {
      // Update global state (will trigger Vue reactivity)
      this.duoChatGlobalState.activeTab = value;
      // Also update cookie for persistence across page loads
      if (value) {
        Cookies.set(ACTIVE_TAB_KEY, value);
      } else {
        Cookies.remove(ACTIVE_TAB_KEY);
      }
    },
    async handleTabToggle(tab) {
      const selected = tab === this.activeTab ? undefined : tab;
      this.setActiveTab(selected);
      if (selected && this.currentTabComponent.initialRoute) {
        // Navigate to the initial route if the tab has one (e.g., sessions)
        this.$router.push(this.currentTabComponent.initialRoute);
      }

      if (['chat', 'new'].includes(tab)) {
        await this.$nextTick();
        this.$refs['content-container']?.getContentComponent()?.focusInput?.();
      }
    },
    closePanel() {
      this.setActiveTab(undefined);
    },
    handleWindowResize() {
      const currentIsDesktop = GlBreakpointInstance.isDesktop();

      // This check ensures that the panel is collapsed only when resizing
      // from desktop to mobile/tablet, not the other way around
      if (this.isDesktop && !currentIsDesktop) {
        this.closePanel();
      }

      this.isDesktop = currentIsDesktop;
    },
    handleWindowFocus() {
      // persist panel's opened state to the currently opened browser tab context
      // this is important for:
      //   1. new tabs opened to have the same panel state as the origin tab
      //   2. current tab initial load/reload to have no layout shift
      this.setActiveTab(this.activeTab);
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-h-full gl-gap-[var(--ai-panels-gap)]">
    <ai-content-container
      v-if="currentTabComponent"
      ref="content-container"
      :user-id="userId"
      :active-tab="currentTabComponent"
      :show-back-button="showBackButton"
      :project-id="projectId"
      :namespace-id="namespaceId"
      :root-namespace-id="rootNamespaceId"
      :resource-id="resourceId"
      :metadata="metadata"
      :user-model-selection-enabled="userModelSelectionEnabled"
      @closePanel="closePanel"
      @go-back="handleGoBack"
      @switch-to-active-tab="setActiveTab"
    />
    <navigation-rail
      :is-expanded="Boolean(currentTabComponent)"
      :active-tab="activeTab"
      :show-suggestions-tab="false"
      @handleTabToggle="handleTabToggle"
    />
  </div>
</template>
