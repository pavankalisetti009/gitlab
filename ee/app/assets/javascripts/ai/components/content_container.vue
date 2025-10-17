<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  name: 'AiContentContainer',
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  i18n: {
    collapseButtonLabel: __('Collapse panel'),
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
  },
  data() {
    return {
      isMaximized: false,
      currentTitle: null,
    };
  },
  computed: {
    goBackTitle() {
      return __('Go back');
    },
    maximizeButtonLabel() {
      return this.isMaximized ? __('Minimize panel') : __('Maximize panel');
    },
  },
  methods: {
    handleGoBack() {
      this.$emit('go-back');
    },
    toggleIsMaximized() {
      this.isMaximized = !this.isMaximized;
    },
    onSwitchToActiveTab(tab) {
      this.$emit('switch-to-active-tab', tab);
    },
    handleTitleChange(title) {
      this.currentTitle = title ?? this.activeTab.title;
    },
  },
};
</script>

<template>
  <aside
    id="ai-panel-portal"
    :aria-label="activeTab.title"
    class="ai-panel !gl-left-auto gl-flex gl-h-full gl-w-[var(--ai-panel-width)] gl-grow gl-flex-col gl-overflow-hidden gl-rounded-[1rem] gl-bg-default [contain:strict]"
    :class="{ 'ai-panel-maximized': isMaximized }"
  >
    <div class="ai-panel-header gl-flex gl-h-[3.0625rem] gl-items-center gl-justify-between">
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
        <h3
          class="gl-m-0 gl-text-sm"
          :class="{ 'gl-ml-4': !showBackButton }"
          data-testid="content-container-title"
        >
          {{ currentTitle || activeTab.title }}
        </h3>
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
          @click="toggleIsMaximized"
        />
      </div>
    </div>
    <div
      class="ai-panel-body gl-grow gl-flex-wrap gl-justify-center gl-overflow-auto gl-text-secondary"
      :class="{ 'gl-flex gl-min-h-full': typeof activeTab.component === 'string' }"
    >
      <div v-if="typeof activeTab.component === 'string'" class="gl-self-center">
        {{ activeTab.component }}
      </div>
      <component
        :is="activeTab.component"
        v-else
        :user-id="userId"
        :project-id="projectId"
        :namespace-id="namespaceId"
        :root-namespace-id="rootNamespaceId"
        :resource-id="resourceId"
        :metadata="metadata"
        :user-model-selection-enabled="userModelSelectionEnabled"
        v-bind="activeTab.props"
        class="gl-h-full"
        @switch-to-active-tab="onSwitchToActiveTab"
        @change-title="handleTitleChange"
      />
    </div>
  </aside>
</template>
