<script>
import { SCANNERS } from '../constants';
import SegmentedBar from './segmented_bar.vue';

export default {
  components: {
    SegmentedBar,
  },
  props: {
    scanners: {
      type: Object,
      required: false,
      default: () =>
        SCANNERS.reduce(
          (scanners, s) => ({
            ...scanners,
            [s.scanner]: Math.random() * 100,
          }),
          {},
        ),
    },
  },
  methods: {
    coverageSegments(scanner) {
      const value = this.scanners[scanner] || 0;
      return [
        { class: 'gl-bg-green-500', count: value },
        { class: 'gl-bg-neutral-200', count: 100 - value },
      ];
    },
  },
  SCANNERS,
};
</script>

<template>
  <div class="gl-flex gl-flex-row gl-gap-2">
    <div v-for="{ scanner, label } in $options.SCANNERS" :key="scanner" class="gl-w-8">
      <segmented-bar
        :aria-labelledby="`${scanner}-label`"
        :segments="coverageSegments(scanner)"
        class="gl-mb-1"
        :data-testid="`${scanner}-bar`"
      />
      <span
        :id="`${scanner}-label`"
        class="gl-text-sm gl-text-status-neutral"
        :data-testid="`${scanner}-label`"
      >
        {{ label }}
        <span class="gl-sr-only">
          {{
            sprintf(s__('SecurityInventory|Tool coverage: %{coverage}%%'), {
              coverage: scanners[scanner],
            })
          }}
        </span>
      </span>
    </div>
  </div>
</template>
