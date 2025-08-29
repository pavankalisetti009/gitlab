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
};
</script>

<template>
  <aside
    v-if="isExpanded"
    :aria-label="__('AI Chat Panel')"
    :aria-hidden="!isExpanded"
    class="gl-w-[400px] gl-rounded-[1rem] gl-bg-default"
  >
    <div class="ai-panel-header gl-flex gl-items-center gl-justify-between">
      <h3 class="gl-m-0 gl-text-sm" data-testid="chat-panel-title">{{ title }}</h3>
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
  </aside>
</template>
