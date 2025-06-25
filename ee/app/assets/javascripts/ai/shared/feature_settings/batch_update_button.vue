<script>
import { GlButton, GlTooltip } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';

export default {
  name: 'BatchUpdateButton',
  components: {
    GlButton,
    GlTooltip,
  },
  props: {
    mainFeature: {
      type: String,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    tooltipTitle() {
      const tooltipText = this.disabled
        ? s__(
            'AdminSelfHostedModels|This model cannot be applied to all %{mainFeature} sub-features',
          )
        : s__('AdminSelfHostedModels|Apply to all %{mainFeature} sub-features');

      return sprintf(tooltipText, { mainFeature: this.mainFeature });
    },
  },
};
</script>
<template>
  <div ref="batchUpdateButton">
    <gl-button
      :aria-label="__('Apply to all button')"
      category="primary"
      icon="duplicate"
      :disabled="disabled"
      @click="$emit('batch-update')"
    />
    <gl-tooltip
      data-testid="model-batch-assignment-tooltip"
      :target="() => $refs.batchUpdateButton"
      :title="tooltipTitle"
    />
  </div>
</template>
