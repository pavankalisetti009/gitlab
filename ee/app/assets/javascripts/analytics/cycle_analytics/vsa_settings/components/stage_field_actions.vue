<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  name: 'StageFieldActions',
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    index: {
      type: Number,
      required: true,
    },
    canRemove: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    hideActionEvent() {
      return this.canRemove ? 'remove' : 'hide';
    },
    hideActionTooltip() {
      return this.canRemove ? __('Remove') : __('Hide');
    },
    hideActionIcon() {
      return this.canRemove ? 'remove' : 'eye-slash';
    },
    hideActionTestId() {
      return `stage-action-${this.canRemove ? 'remove' : 'hide'}-${this.index}`;
    },
  },
};
</script>
<template>
  <div>
    <gl-button
      v-gl-tooltip
      category="tertiary"
      :title="hideActionTooltip"
      :aria-label="hideActionTooltip"
      :data-testid="hideActionTestId"
      :icon="hideActionIcon"
      @click="$emit(hideActionEvent, index)"
    />
  </div>
</template>
