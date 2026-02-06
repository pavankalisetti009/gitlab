<script>
import { GlButton, GlDisclosureDropdown, GlTooltipDirective, GlSkeletonLoader } from '@gitlab/ui';
import SafeHtmlDirective from '~/vue_shared/directives/safe_html';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import { __, sprintf } from '~/locale';
import { AGENTS_PLATFORM_SHOW_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';
import { copyToClipboard } from '~/lib/utils/copy_to_clipboard';
import showGlobalToast from '~/vue_shared/plugins/global_toast';
import {
  formatAgentFlowName,
  agentSessionProjectVar,
  agentSessionFlowDefinitionVar,
} from 'ee/ai/duo_agents_platform/utils';

export default {
  name: 'AiContentContainer',
  expose: ['getContentComponent'],
  components: {
    GlButton,
    GlDisclosureDropdown,
    GlSkeletonLoader,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
    SafeHtml: SafeHtmlDirective,
  },
  inject: ['chatConfiguration'],
  i18n: {
    collapseButtonLabel: __('Collapse panel'),
    moreOptionsLabel: __('More options'),
    copySessionIdTooltip: __('Copy Chat Session ID: %{id}'),
    sessionIdCopiedToast: __('Session ID copied to clipboard'),
    sessionIdCopyFailedToast: __('Could not copy session ID'),
  },
  props: {
    activeTab: {
      type: Object,
      required: true,
      validator(activeTabObject) {
        return typeof activeTabObject?.title === 'string';
      },
    },
    showBackButton: {
      type: Boolean,
      required: false,
      default: false,
    },
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
    selectedAgent: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    isMaximized: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      currentTitle: null,
      duoChatGlobalState,
      agentSessionProject: agentSessionProjectVar(),
      agentSessionFlowDefinition: agentSessionFlowDefinitionVar(),
      sessionId: null,
      isSessionDropdownVisible: false,
    };
  },
  computed: {
    goBackTitle() {
      return __('Go back');
    },
    maximizeButtonLabel() {
      return this.isMaximized ? __('Minimize panel') : __('Maximize panel');
    },
    componentKey() {
      // Include chatMode in the key to force component recreation when switching
      // between modes, ensuring state doesn't persist
      const componentName = this.activeTab.component?.name || 'component';
      return `${componentName}-${this.duoChatGlobalState.chatMode}`;
    },
    isShowSessionRoute() {
      return this.$route.name === AGENTS_PLATFORM_SHOW_ROUTE;
    },
    showSessionId() {
      return this.sessionId && this.activeTab.props.mode === 'active';
    },
    sessionText() {
      return sprintf(this.$options.i18n.copySessionIdTooltip, { id: this.sessionId });
    },
    sessionIdItems() {
      return [
        {
          text: this.sessionText,
          action: () => {
            this.copySessionIdToClipboard();
          },
        },
      ];
    },
    showSessionDropdownTooltip() {
      return !this.isSessionDropdownVisible ? this.$options.i18n.moreOptionsLabel : '';
    },
    projectName() {
      return this.agentSessionProject?.name;
    },
    sessionDefinition() {
      return formatAgentFlowName(this.agentSessionFlowDefinition, this.$route?.params?.id);
    },
    displayTitle() {
      return (
        (this.isShowSessionRoute && this.projectName) || this.currentTitle || this.activeTab.title
      );
    },
  },
  watch: {
    'activeTab.title': {
      handler(newTitle) {
        // Reset currentTitle when the prop title changes
        if (!this.currentTitle || this.currentTitle !== newTitle) {
          this.currentTitle = null;
        }
      },
    },
  },
  mounted() {
    // We need to re-subscribe each time for onNextChange
    this.unsubscribers = [
      agentSessionProjectVar.onNextChange((newVal) => {
        this.agentSessionProject = newVal;
      }),
      agentSessionFlowDefinitionVar.onNextChange((newVal) => {
        this.agentSessionFlowDefinition = newVal;
      }),
    ];
  },
  beforeDestroy() {
    this.unsubscribers?.forEach((unsubscribe) => unsubscribe());
  },
  methods: {
    handleGoBack() {
      this.$emit('go-back');
    },
    onSwitchToActiveTab(tab) {
      this.$emit('switch-to-active-tab', tab);
    },
    handleTitleChange(title) {
      this.currentTitle = title ?? this.activeTab.title;
    },
    getContentComponent() {
      return this.$refs['content-component'];
    },
    handleSessionIdChanged(sessionId) {
      this.sessionId = sessionId;
    },
    showSessionDropdown() {
      this.isSessionDropdownVisible = true;
    },
    hideSessionDropdown() {
      this.isSessionDropdownVisible = false;
    },
    async copySessionIdToClipboard() {
      try {
        await copyToClipboard(this.sessionId);
        showGlobalToast(this.$options.i18n.sessionIdCopiedToast);
      } catch {
        showGlobalToast(this.$options.i18n.sessionIdCopyFailedToast);
      }
    },
  },
};
</script>

<template>
  <aside
    id="ai-panel-portal"
    :aria-label="activeTab.title"
    class="ai-panel !gl-left-auto gl-flex gl-h-full gl-w-[var(--ai-panel-width)] gl-grow gl-flex-col gl-rounded-[1rem] gl-bg-default [contain:strict] lg:gl-mr-2"
  >
    <div
      class="ai-panel-header gl-flex gl-h-[3.0625rem] gl-items-center gl-justify-between"
      :class="{ 'gl-min-h-[3.0625rem]': typeof activeTab.component === 'string' }"
    >
      <div
        class="gl-flex gl-max-w-17/20 gl-flex-1 gl-shrink-0 gl-items-center gl-justify-start gl-gap-2 gl-overflow-hidden gl-truncate gl-text-ellipsis gl-whitespace-nowrap"
      >
        <gl-button
          v-gl-tooltip.bottom
          class="lg:gl-flex"
          :class="{ '!gl-hidden': !showBackButton }"
          icon="go-back"
          category="tertiary"
          :aria-label="goBackTitle"
          :title="goBackTitle"
          data-testid="content-container-back-button"
          @click="handleGoBack"
        />
        <div class="gl-flex gl-w-full gl-flex-col">
          <gl-skeleton-loader v-if="isShowSessionRoute && !projectName" :lines="2" />
          <div v-else>
            <h3
              class="gl-m-0 gl-truncate gl-text-sm"
              :class="{ 'gl-ml-4': !showBackButton }"
              data-testid="content-container-title"
            >
              {{ displayTitle }}
            </h3>
            <h4
              v-if="isShowSessionRoute"
              class="gl-m-0 gl-mt-1 gl-truncate gl-text-sm gl-font-normal"
              data-testid="content-container-subtitle"
            >
              {{ sessionDefinition }}
            </h4>
          </div>
        </div>
      </div>

      <div class="ai-panel-header-actions gl-flex gl-gap-x-2 gl-pr-3">
        <gl-button
          v-gl-tooltip.bottom
          icon="dash"
          category="tertiary"
          size="small"
          :aria-label="$options.i18n.collapseButtonLabel"
          :title="$options.i18n.collapseButtonLabel"
          aria-expanded
          data-testid="content-container-collapse-button"
          @click="$emit('closePanel', false)"
        />
        <gl-button
          v-gl-tooltip.bottom
          class="gl-hidden lg:gl-flex"
          :icon="isMaximized ? 'minimize' : 'maximize'"
          category="tertiary"
          size="small"
          :aria-label="maximizeButtonLabel"
          :title="maximizeButtonLabel"
          data-testid="content-container-maximize-button"
          @click="$emit('toggleMaximize')"
        />
      </div>
    </div>
    <div
      class="ai-panel-body gl-grow gl-flex-wrap gl-justify-center gl-overflow-auto"
      :class="{ 'gl-flex gl-min-h-full': typeof activeTab.component === 'string' }"
    >
      <div
        v-if="typeof activeTab.component === 'string'"
        v-safe-html="activeTab.component"
        class="gl-self-center gl-p-5"
      ></div>
      <component
        :is="activeTab.component"
        v-else
        ref="content-component"
        :key="componentKey"
        :user-id="userId"
        :project-id="projectId"
        :namespace-id="namespaceId"
        :root-namespace-id="rootNamespaceId"
        :resource-id="resourceId"
        :metadata="metadata"
        :selected-agent="selectedAgent"
        :user-model-selection-enabled="userModelSelectionEnabled"
        v-bind="activeTab.props"
        class="gl-h-full"
        @switch-to-active-tab="onSwitchToActiveTab"
        @change-title="handleTitleChange"
        @session-id-changed="handleSessionIdChanged"
      >
        <template #header>
          <gl-disclosure-dropdown
            v-if="showSessionId"
            v-gl-tooltip="showSessionDropdownTooltip"
            icon="ellipsis_v"
            category="tertiary"
            text-sr-only
            size="small"
            :toggle-text="$options.i18n.moreOptionsLabel"
            :items="sessionIdItems"
            no-caret
            data-testid="content-container-session-menu"
            @shown="showSessionDropdown"
            @hidden="hideSessionDropdown"
          />
        </template>
      </component>
    </div>
  </aside>
</template>
