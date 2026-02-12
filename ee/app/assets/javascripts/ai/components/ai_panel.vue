<script>
import { GlBreakpointInstance } from '@gitlab/ui/src/utils'; // eslint-disable-line no-restricted-syntax -- GlBreakpointInstance is used intentionally here. In this case we must obtain viewport breakpoints
import { __ } from '~/locale';
import AgentSessionsRoot from '~/vue_shared/spa/components/spa_root.vue';
import { CHAT_MODES } from 'ee/ai/tanuki_bot/constants';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import dismissUserCalloutMutation from '~/graphql_shared/mutations/dismiss_user_callout.mutation.graphql';
import { setAiPanelTab } from '../graphql';
import activeTabQuery from '../graphql/active_tab.query.graphql';
import AiContentContainer from './content_container.vue';
import NavigationRail from './navigation_rail.vue';

const DUO_PANEL_AUTO_EXPANDED_CALLOUT = 'duo_panel_auto_expanded';

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
    chatDisabledReason: {
      type: String,
      required: false,
      default: '',
    },
  },
  apollo: {
    activeTab: {
      query: activeTabQuery,
      result({ data }) {
        if (data?.activeTab) {
          this.handleChangeTab(data.activeTab);
        }
      },
    },
  },
  data() {
    return {
      activeTab: undefined,
      isDesktop: GlBreakpointInstance.isDesktop(),
      duoChatGlobalState,
      selectedAgentError: null,
      isMaximized: false,
    };
  },
  computed: {
    isChatDisabled() {
      return Boolean(this.chatDisabledReason);
    },
    isAgenticMode() {
      return (
        this.chatConfiguration.defaultProps.isAgenticAvailable &&
        this.duoChatGlobalState.chatMode === CHAT_MODES.AGENTIC
      );
    },
    currentChatComponent() {
      const { agenticComponent, classicComponent, defaultProps } = this.chatConfiguration;
      const { agenticUnavailableMessage, isClassicAvailable } = defaultProps;
      if (this.isAgenticMode) {
        return agenticComponent;
      }
      if (agenticUnavailableMessage) {
        return agenticUnavailableMessage;
      }
      if (isClassicAvailable) {
        return classicComponent;
      }
      return __('Chat is not available.');
    },
    currentChatTitle() {
      return this.isAgenticMode
        ? this.chatConfiguration.agenticTitle
        : this.chatConfiguration.classicTitle;
    },
    currentTabComponent() {
      if (this.isChatDisabled) {
        return null;
      }

      const chatMode = this.isAgenticMode ? 'active' : 'chat';

      switch (this.activeTab) {
        case 'chat':
          return {
            title: this.currentChatTitle,
            component: this.currentChatComponent,
            props: { mode: chatMode, ...this.chatConfiguration.defaultProps },
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
            title: __('Sessions'),
            component: AgentSessionsRoot,
            initialRoute: '/agent-sessions/',
          };
        default:
          return null;
      }
    },
    showBackButton() {
      return (
        this.currentTabComponent?.initialRoute &&
        this.currentTabComponent?.initialRoute !== this.$route.path
      );
    },
  },
  watch: {
    'duoChatGlobalState.focusChatInput': {
      handler(newVal) {
        if (newVal) {
          duoChatGlobalState.focusChatInput = false; // reset global state
          this.focusInput();
        }
      },
    },
    isMaximized: {
      handler(maximized) {
        document.querySelector('.js-page-layout').classList.toggle('ai-panel-maximized', maximized);
      },
      immediate: true,
    },
  },
  mounted() {
    window.addEventListener('resize', this.handleWindowResize);
    window.addEventListener('focus', this.handleWindowFocus);

    if (this.chatDisabledReason) {
      this.setActiveTab(undefined);
    }
  },
  beforeDestroy() {
    window.removeEventListener('resize', this.handleWindowResize);
    window.removeEventListener('focus', this.handleWindowFocus);
  },
  methods: {
    handleGoBack() {
      this.$router.push(this.currentTabComponent?.initialRoute || '/');
    },
    setActiveTab(value) {
      setAiPanelTab(value);

      const unwatchTabChanges = this.$watch('activeTab', async (tab) => {
        if (['chat', 'new'].includes(tab)) {
          await this.$nextTick();
          this.focusInput();
        }

        unwatchTabChanges();
      });
    },
    async handleNewChat() {
      this.setActiveTab('new');
    },
    async handleTabToggle(tab) {
      // Clicking on the icon of active tab acts as a toggle
      if (this.activeTab === tab) {
        this.closePanel();
        return;
      }

      this.setActiveTab(tab);
    },
    async handleChangeTab(tab) {
      const targetRoute =
        this.duoChatGlobalState.lastRoutePerTab[tab] ||
        this.currentTabComponent?.initialRoute ||
        '/';

      // sometimes the router is already set to the route of the tab before the tab is opened.
      // if that is the case, do not navigate to the last route per tab or initial route.

      if (targetRoute === '/' || !this.$route.path.includes(targetRoute)) {
        await this.$router.push(targetRoute).catch(() => {});
      }
    },
    closePanel() {
      this.setActiveTab(undefined);
      this.isMaximized = false;
      this.dismissAutoExpandCallout();
    },
    async dismissAutoExpandCallout() {
      try {
        await this.$apollo.mutate({
          mutation: dismissUserCalloutMutation,
          variables: {
            input: {
              featureName: DUO_PANEL_AUTO_EXPANDED_CALLOUT,
            },
          },
        });
      } catch {
        // Silently ignore errors - callout dismissal is non-critical
      }
    },
    focusInput() {
      this.$refs['content-container']?.getContentComponent()?.focusInput?.();
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
    handleNewChatError(error) {
      this.selectedAgentError = error;
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
      :agent-select-error="selectedAgentError"
      :is-maximized="isMaximized"
      @closePanel="closePanel"
      @go-back="handleGoBack"
      @switch-to-active-tab="setActiveTab"
      @toggleMaximize="isMaximized = !isMaximized"
    />
    <navigation-rail
      :is-expanded="Boolean(currentTabComponent)"
      :active-tab="activeTab"
      :show-suggestions-tab="false"
      :chat-disabled-reason="chatDisabledReason"
      :project-id="projectId"
      :namespace-id="namespaceId"
      :is-agentic-mode="isAgenticMode"
      @handleTabToggle="handleTabToggle"
      @new-chat="handleNewChat"
      @newChatError="handleNewChatError"
    />
  </div>
</template>
