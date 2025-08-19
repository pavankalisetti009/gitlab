<script>
import { GlSkeletonLoader, GlTooltipDirective } from '@gitlab/ui';
import { GlSparklineChart } from '@gitlab/ui/dist/charts';
import { TREND_STYLES, TREND_STYLE_ASC, TREND_STYLE_DESC } from '../../../../dashboards/constants';

export default {
  name: 'TrendLine',
  components: {
    GlSkeletonLoader,
    GlSparklineChart,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    data: {
      type: Array,
      required: true,
    },
    tooltipLabel: {
      type: String,
      required: false,
      default: '',
    },
    trendStyle: {
      type: String,
      required: false,
      default: TREND_STYLE_ASC,
      validator: (style) => TREND_STYLES.includes(style),
    },
  },
  computed: {
    gradient() {
      const colors = ['#499767', '#5252B5'];

      switch (this.trendStyle) {
        case TREND_STYLE_ASC:
          return colors;
        case TREND_STYLE_DESC:
          return colors.reverse();
        default:
          return [];
      }
    },
  },
};
</script>
<template>
  <div>
    <gl-sparkline-chart
      v-if="data.length"
      :height="30"
      :tooltip-label="tooltipLabel"
      :show-last-y-value="false"
      :data="data"
      :smooth="0.2"
      :gradient="gradient"
      connect-nulls
      data-testid="metric-chart"
    />
    <div v-else class="gl-py-4" data-testid="metric-chart-skeleton">
      <gl-skeleton-loader :lines="1" :width="100" />
    </div>
  </div>
</template>
