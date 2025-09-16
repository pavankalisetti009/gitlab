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
    collapseButtonLabel: __('Collapse GitLab Duo Panel'),
  },
  props: {
    activeTab: {
      type: Object,
      required: true,
    },
    isExpanded: {
      type: Boolean,
      required: true,
    },
    showBackButton: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      isMaximized: false,
    };
  },
  computed: {
    goBackTitle() {
      return __('Go back');
    },
    maximizeButtonLabel() {
      return this.isMaximized ? __('Minimize Duo Panel') : __('Maximize Duo Panel');
    },
  },
  methods: {
    handleGoBack() {
      this.$emit('go-back');
    },
    toggleIsMaximized() {
      this.isMaximized = !this.isMaximized;
    },
  },
};
</script>
<template>
  <aside
    v-if="isExpanded"
    id="ai-panel-portal"
    :aria-label="activeTab.title"
    :aria-hidden="!isExpanded"
    class="ai-panel !gl-left-auto gl-h-full gl-w-[400px] gl-grow gl-overflow-hidden gl-rounded-[1rem] gl-bg-default [contain:strict]"
    :class="{ 'ai-panel-maximized': isMaximized }"
  >
    <div class="ai-panel-header gl-flex gl-items-center gl-justify-between">
      <div class="gl-flex gl-items-center gl-justify-start gl-gap-2">
        <gl-button
          v-gl-tooltip
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
          {{ activeTab.title }}
        </h3>
      </div>

      <div class="ai-panel-header-actions gl-flex">
        <gl-button
          v-gl-tooltip
          class="gl-hidden lg:gl-flex"
          :icon="isMaximized ? 'minimize' : 'maximize'"
          category="tertiary"
          :aria-label="maximizeButtonLabel"
          :title="maximizeButtonLabel"
          data-testid="content-container-maximize-button"
          @click="toggleIsMaximized"
        />
        <gl-button
          v-gl-tooltip
          icon="dash"
          category="tertiary"
          :aria-label="$options.i18n.collapseButtonLabel"
          :title="$options.i18n.collapseButtonLabel"
          :aria-expanded="isExpanded"
          data-testid="content-container-collapse-button"
          @click="$emit('closePanel', false)"
        />
      </div>
    </div>
    <div class="ai-panel-body gl-overflow-auto gl-p-5 gl-text-sm gl-text-secondary">
      <div v-if="typeof activeTab.component === 'string'">
        {{ activeTab.component }}
      </div>
      <component :is="activeTab.component" v-else />
    </div>
  </aside>
</template>
