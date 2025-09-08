<script>
import { GlResizeObserverDirective } from '@gitlab/ui';
import { generateGrid } from 'ee/security_dashboard/utils/chart_utils';
import { s__, sprintf } from '~/locale';

export default {
  directives: {
    GlResizeObserver: GlResizeObserverDirective,
  },
  props: {
    riskScores: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      nrCols: 0,
      nrRows: 0,
    };
  },
  riskScoreClasses: {
    LOW: 'gl-bg-green-200 gl-text-green-800',
    MEDIUM: 'gl-bg-orange-200 gl-text-orange-800',
    HIGH: 'gl-bg-red-500 gl-text-white',
    CRITICAL: 'gl-bg-red-700 gl-text-white',
  },
  computed: {
    gridStyle() {
      return `grid-template-columns: repeat(${this.nrCols}, 1fr); grid-template-rows: repeat(${this.nrRows}, 1fr);`;
    },
  },
  methods: {
    updateGridDimensions({ contentRect: { width, height } }) {
      if (!width || !height) return;

      const { rows, cols } = generateGrid({
        totalItems: this.riskScores.length,
        width,
        height,
      });
      this.nrRows = rows;
      this.nrCols = cols;
    },
    getAriaLabel(riskScore) {
      return sprintf(s__('SecurityReports|Project %{project}, risk score: %{riskScore}'), {
        project: riskScore.project.name,
        riskScore: riskScore.score,
      });
    },
  },
};
</script>

<template>
  <div
    v-gl-resize-observer="updateGridDimensions"
    class="gl-grid gl-h-full gl-gap-1"
    :style="gridStyle"
  >
    <div
      v-for="riskScore in riskScores"
      :key="riskScore.project.id"
      :aria-label="getAriaLabel(riskScore)"
      class="gl-flex gl-items-center gl-justify-center gl-bg-gray-200"
      :class="$options.riskScoreClasses[riskScore.rating]"
      data-testid="risk-score-tile"
    >
      {{ riskScore.score }}
    </div>
  </div>
</template>
