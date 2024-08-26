<script>
import { GlTooltip, GlIcon } from '@gitlab/ui';
import { getIterationPeriod } from 'ee/iterations/utils';

export default {
  components: {
    GlTooltip,
    GlIcon,
  },
  props: {
    iteration: {
      type: Object,
      required: true,
    },
  },
  computed: {
    iterationPeriod() {
      return getIterationPeriod(this.iteration, true);
    },
    showIterationCadenceTitle() {
      return this.iteration.iterationCadence?.title !== undefined;
    },
  },
};
</script>

<template>
  <span ref="iteration" class="board-card-info gl-cursor-help gl-text-sm gl-text-secondary">
    <gl-icon class="board-card-info-icon flex-shrink-0 gl-mr-2" name="iteration" />
    <span class="board-card-info gl-mr-3" data-testid="issue-iteration-body">
      {{ iterationPeriod }}
    </span>
    <gl-tooltip
      :target="() => $refs.iteration"
      placement="bottom"
      data-testid="issue-iteration-info"
    >
      <div class="gl-font-bold">{{ __('Iteration') }}</div>
      <div v-if="showIterationCadenceTitle" data-testid="issue-iteration-cadence-title">
        {{ iteration.iterationCadence.title }}
      </div>
      <div data-testid="issue-iteration-period">{{ iterationPeriod }}</div>
      <div v-if="iteration.title" data-testid="issue-iteration-title">{{ iteration.title }}</div>
    </gl-tooltip>
  </span>
</template>
