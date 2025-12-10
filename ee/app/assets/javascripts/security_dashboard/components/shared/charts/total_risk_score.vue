<script>
import { GlResizeObserverDirective } from '@gitlab/ui';
import { GlChart } from '@gitlab/ui/src/charts';
import { s__ } from '~/locale';

const RATING_LABELS = {
  LOW: s__('SecurityReports|Low risk'),
  MEDIUM: s__('SecurityReports|Medium risk'),
  HIGH: s__('SecurityReports|High risk'),
  CRITICAL: s__('SecurityReports|Critical risk'),
};

export default {
  components: {
    GlChart,
  },
  directives: {
    GlResizeObserver: GlResizeObserverDirective,
  },
  props: {
    score: {
      type: Number,
      required: true,
      validator: (value) => value >= 0 && value <= 100,
    },
  },
  data() {
    return {
      chartWidth: 0,
      chartHeight: 0,
    };
  },
  computed: {
    label() {
      return RATING_LABELS[this.rating];
    },
    labelTextColor() {
      return `var(--risk-score-gauge-text-${this.rating.toLowerCase()})`;
    },
    rating() {
      if (this.score <= 25) {
        return 'LOW';
      }

      if (this.score <= 50) {
        return 'MEDIUM';
      }

      if (this.score <= 75) {
        return 'HIGH';
      }

      return 'CRITICAL';
    },
    chartOptions() {
      return {
        series: [this.outerMeterRing, this.progressMeterRing],
      };
    },
    gaugeDimensions() {
      // the center is slightly raised, because a gauge chart is usually a full circle, but we don't display the bottom part of the circle
      const centerXPercent = 0.5;
      const centerYPercent = 0.6;

      const gapBetweenRingsInPx = 1;
      const outerMeterMaxWidthInPx = 15;
      const outerRingWidthRatio = 0.2;

      const cx = this.chartWidth * centerXPercent;
      const cy = this.chartHeight * centerYPercent;

      // the radius of the outer meter ring is the smallest distance from the center to the edge of the chart
      const outerMeterRadiusInPx = Math.min(cx, this.chartWidth - cx, cy, this.chartHeight - cy);

      const outerMeterRingWidth = Math.min(
        outerMeterMaxWidthInPx,
        Math.round(outerMeterRadiusInPx * outerRingWidthRatio),
      );

      const progressMeterRadiusInPx =
        outerMeterRadiusInPx - outerMeterRingWidth - gapBetweenRingsInPx;
      const progressMeterRingWidth = outerMeterRingWidth * 2;

      return {
        centerXPercent,
        centerYPercent,
        outerMeter: {
          radius: outerMeterRadiusInPx,
          ringWidth: outerMeterRingWidth,
        },
        progressMeter: {
          radius: progressMeterRadiusInPx,
          ringWidth: progressMeterRingWidth,
        },
      };
    },
    outerMeterRing() {
      return {
        type: 'gauge',
        startAngle: 220,
        endAngle: -40,
        min: 0,
        max: 100,
        splitNumber: 4,
        center: [
          `${this.gaugeDimensions.centerXPercent * 100}%`,
          `${this.gaugeDimensions.centerYPercent * 100}%`,
        ],
        radius: this.gaugeDimensions.outerMeter.radius,
        axisLine: {
          lineStyle: {
            width: this.gaugeDimensions.outerMeter.ringWidth,
            color: [
              [0.25, this.getRiskScoreColor('LOW')],
              [0.5, this.getRiskScoreColor('MEDIUM')],
              [0.75, this.getRiskScoreColor('HIGH')],
              [1, this.getRiskScoreColor('CRITICAL')],
            ],
          },
        },
        pointer: {
          show: false,
        },
        axisTick: {
          show: true,
          lineStyle: {
            color: '#fff',
            width: 1,
          },
          length: 6,
          distance: -this.gaugeDimensions.outerMeter.ringWidth,
        },
        splitLine: {
          show: false,
        },
        axisLabel: {
          show: false,
        },
        // the risk rating label (e.g. "Low risk")
        detail: {
          show: true,
          width: 100,
          height: 40,
          offsetCenter: [0, -20],
          fontSize: 45,
          color: this.labelTextColor,
        },
        title: {
          show: true,
          offsetCenter: [0, 15], // Position below the risk rating label
          fontSize: 17,
          color: this.labelTextColor,
        },
        // the score value displayed as a number
        data: [
          {
            value: this.score,
            name: this.label,
          },
        ],
      };
    },
    progressMeterRing() {
      return {
        type: 'gauge',
        startAngle: 220,
        endAngle: -40,
        min: 0,
        max: 100,
        splitNumber: 4,
        center: [
          `${this.gaugeDimensions.centerXPercent * 100}%`,
          `${this.gaugeDimensions.centerYPercent * 100}%`,
        ],
        radius: this.gaugeDimensions.progressMeter.radius,
        axisLine: {
          show: true,
          lineStyle: {
            width: this.gaugeDimensions.progressMeter.ringWidth,
            color: [
              // the actual data representation
              [this.score / 100, this.getRiskScoreColor(this.rating)],
              // transparent to support dark and light mode
              [1, 'transparent'],
            ],
          },
        },
        pointer: {
          show: false,
        },
        axisTick: {
          show: false,
        },
        splitLine: {
          show: false,
        },
        axisLabel: {
          show: false,
        },
        title: {
          show: false,
        },
        detail: {
          show: false,
        },
        data: [
          {
            value: this.score,
          },
        ],
      };
    },
  },
  methods: {
    onResize({ contentRect: { width, height } }) {
      this.chartWidth = width;
      this.chartHeight = height;
    },
    getRiskScoreColor(rating) {
      return `var(--risk-score-color-${rating.toLowerCase()})`;
    },
  },
};
</script>

<template>
  <div
    v-gl-resize-observer="onResize"
    class="gl-justify-content-center gl-align-items-center gl-flex gl-h-full gl-w-full"
  >
    <gl-chart :options="chartOptions" responsive height="auto" class="gl-h-full gl-w-full" />
  </div>
</template>
