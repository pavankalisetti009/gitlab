<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  name: 'NavigationRail',
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  i18n: {
    duoChatLabel: __('GitLab Duo Chat'),
  },
  props: {
    isExpanded: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  methods: {
    handleIconClick() {
      // TODO: Set up logic for switching AI modes and expanding the panel
      if (!this.isExpanded) this.$emit('toggleAIPanel', true);
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-w-[32px] gl-flex-col gl-bg-transparent gl-pt-3">
    <gl-button
      v-gl-tooltip
      class="!gl-rounded-lg"
      :class="['ai-nav-icon', { 'ai-nav-icon-active': isExpanded }]"
      icon="comment"
      category="tertiary"
      data-testid="ai-chat-toggle"
      triggers="hover"
      :title="$options.i18n.duoChatLabel"
      :aria-label="$options.i18n.duoChatLabel"
      :aria-expanded="isExpanded"
      @click="handleIconClick"
    />
  </div>
</template>
