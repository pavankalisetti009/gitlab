<script>
import { GlTooltip, GlIcon } from '@gitlab/ui';

export default {
  name: 'IssueCardWeight',
  components: {
    GlIcon,
    GlTooltip,
  },
  props: {
    weight: {
      type: Number,
      required: true,
    },
  },
};
</script>

<template>
  <div
    ref="itemWeight"
    class="board-card-info board-card-weight gl-mr-3 gl-inline-flex gl-cursor-help gl-items-center gl-align-bottom gl-text-sm gl-text-gray-500"
    v-on="$listeners"
  >
    <gl-icon name="weight" class="board-card-info-icon gl-mr-2" />
    <span data-testid="board-card-weight" class="board-card-info-text"> {{ weight }} </span>
    <gl-tooltip :target="() => $refs.itemWeight" placement="bottom" container="body"
      >{{ __('Weight') }}<br /><span class="gl-text-tertiary">{{ weight }}</span>
    </gl-tooltip>
  </div>
</template>
