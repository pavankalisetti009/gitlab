<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  name: 'ChatPanel',
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  i18n: {
    collapseButtonLabel: __('Collapse GitLab Duo Chat'),
  },
  props: {
    title: {
      type: String,
      required: true,
    },
    isExpanded: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      isMaximized: false,
    };
  },
  computed: {
    maximizeButtonLabel() {
      return this.isMaximized ? __('Minimize Duo Panel') : __('Maximize Duo Panel');
    },
  },
  methods: {
    toggleIsMaximized() {
      this.isMaximized = !this.isMaximized;
    },
  },
};
</script>

<template>
  <aside
    v-if="isExpanded"
    :aria-label="__('AI Chat Panel')"
    :aria-hidden="!isExpanded"
    class="!gl-left-auto gl-h-full gl-w-[400px] gl-grow gl-overflow-hidden gl-rounded-[1rem] gl-bg-default"
    :class="{ 'ai-panel-maximized': isMaximized }"
  >
    <div class="ai-panel-header gl-flex gl-items-center gl-justify-between">
      <h3 class="gl-m-0 gl-text-sm" data-testid="chat-panel-title">{{ title }}</h3>
      <div class="ai-panel-header-actions gl-flex">
        <gl-button
          v-gl-tooltip
          class="gl-hidden lg:gl-flex"
          icon="maximize"
          category="tertiary"
          :aria-label="maximizeButtonLabel"
          :title="maximizeButtonLabel"
          data-testid="chat-panel-maximize-button"
          @click="toggleIsMaximized"
        />
        <gl-button
          v-gl-tooltip
          icon="dash"
          category="tertiary"
          :aria-label="$options.i18n.collapseButtonLabel"
          :title="$options.i18n.collapseButtonLabel"
          :aria-expanded="isExpanded"
          data-testid="chat-panel-collapse-button"
          @click="$emit('closePanel', false)"
        />
      </div>
    </div>
  </aside>
</template>
