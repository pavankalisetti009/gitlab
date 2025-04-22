<script>
import { SCANNER_TYPES, SCANNER_POPOVER_GROUPS } from '../constants';
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
        Object.entries(SCANNER_POPOVER_GROUPS).reduce(
          (scanners, [key]) => ({
            ...scanners,
            [key]: Math.random() * 100,
          }),
          {},
        ),
    },
  },
  methods: {
    coverageSegments(key) {
      const value = this.scanners[key] || 0;
      return [
        { class: 'gl-bg-green-500', count: value },
        { class: 'gl-bg-neutral-200', count: 100 - value },
      ];
    },
    getLabel(key) {
      return SCANNER_TYPES[key].textLabel;
    },
  },
  SCANNER_POPOVER_GROUPS,
};
</script>

<template>
  <div class="gl-flex gl-flex-row gl-gap-2">
    <div v-for="(value, key) in $options.SCANNER_POPOVER_GROUPS" :key="key" class="gl-w-8">
      <segmented-bar
        :aria-labelledby="`${key}-label`"
        :segments="coverageSegments(key)"
        class="gl-mb-1"
        :data-testid="`${key}-bar`"
      />
      <span
        :id="`${key}-label`"
        class="gl-text-sm gl-text-status-neutral"
        :data-testid="`${key}-label`"
      >
        {{ getLabel(key) }}
        <span class="gl-sr-only">
          {{
            sprintf(s__('SecurityInventory|Tool coverage: %{coverage}%%'), {
              coverage: scanners[key],
            })
          }}
        </span>
      </span>
    </div>
  </div>
</template>
