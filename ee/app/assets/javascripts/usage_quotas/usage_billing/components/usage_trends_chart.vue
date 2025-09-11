<script>
import { GlCard, GlButton, GlBadge } from '@gitlab/ui';
import { GlAreaChart } from '@gitlab/ui/src/charts';
import { s__, __ } from '~/locale';
import { numberToMetricPrefix } from '~/lib/utils/number_utils';
import { localeDateFormat } from '~/lib/utils/datetime/locale_dateformat';

export default {
  name: 'UsageTrendsChart',
  components: {
    GlCard,
    GlButton,
    GlAreaChart,
    GlBadge,
  },
  props: {
    usageData: {
      type: Array,
      required: true,
    },
    monthStartDate: {
      type: String,
      required: true,
    },
    monthEndDate: {
      type: String,
      required: true,
    },
    trend: {
      type: Number,
      required: true,
    },
    dailyPeak: {
      type: Number,
      required: true,
    },
    dailyAverage: {
      type: Number,
      required: true,
    },
  },
  data() {
    return {
      chartData: [
        {
          name: s__('UsageBilling|Daily usage'),
          data: this.usageData,
        },
      ],
    };
  },
  computed: {
    usageTrend() {
      if (this.trend >= 0.5) {
        return 'success';
      }

      if (this.trend === 0) {
        return 'danger';
      }

      return 'neutral';
    },
    usageTrendVariant() {
      switch (this.usageTrend) {
        case 'success':
          return { textClass: 'gl-text-green-500', badgeIcon: 'trend-up' };
        case 'danger':
          return { textClass: 'gl-text-red-500', badgeIcon: 'trend-down' };
        default:
          return { textClass: '', badgeIcon: 'trend-static' };
      }
    },
    formattedRange() {
      return localeDateFormat.asDate.formatRange(
        new Date(this.monthStartDate),
        new Date(this.monthEndDate),
      );
    },
  },
  chartOptions: {
    xAxis: { name: __('Date'), type: 'category' },
    yAxis: { name: s__('UsageBilling|Tokens') },
  },
  methods: {
    numberToMetricPrefix,
  },
};
</script>
<template>
  <gl-card class="bg-transparent gl-flex-1">
    <header class="gl-my-3 gl-flex gl-flex-col gl-justify-between gl-gap-3 sm:gl-flex-row">
      <h2 class="gl-font-heading gl-heading-scale-400" data-testid="chart-heading">
        {{ formattedRange }}
      </h2>
      <div class="gl-flex gl-flex-col gl-justify-between gl-gap-3 sm:gl-flex-row">
        <gl-button size="small">{{ s__('UsageBilling|Last 3 months') }}</gl-button>
        <gl-button size="small">{{ s__('UsageBilling|Last month') }}</gl-button>
        <gl-button size="small">{{ s__('UsageBilling|Current month') }}</gl-button>
        <gl-button size="small">{{ s__('UsageBilling|Custom dates') }}</gl-button>
      </div>
    </header>

    <gl-area-chart :data="chartData" :option="$options.chartOptions" width="auto" />
    <div class="gl-mb-2 gl-mt-5 gl-flex gl-flex-row gl-gap-5">
      <gl-card class="bg-transparent gl-flex-1">
        <p class="gl-font-heading gl-heading-scale-400">
          {{ numberToMetricPrefix(dailyAverage) }}
        </p>
        <p class="gl-mb-2">{{ s__('UsageBilling|Daily average use') }}</p>
      </gl-card>

      <gl-card class="bg-transparent gl-flex-1">
        <p class="gl-font-heading gl-heading-scale-400">
          {{ numberToMetricPrefix(dailyPeak) }}
        </p>
        <p class="gl-mb-2">{{ s__('UsageBilling|Peak daily use') }}</p>
      </gl-card>

      <gl-card class="bg-transparent gl-flex-1">
        <p
          :class="`gl-font-heading gl-heading-scale-400 ${usageTrendVariant.textClass}`"
          data-testid="usage-trend-title"
        >
          {{ Math.round(trend * 100) }}%
          <gl-badge :icon="usageTrendVariant.badgeIcon" :variant="usageTrend" icon-size="sm" />
        </p>
        <p class="gl-mb-2">{{ s__('UsageBilling|Usage trend') }}</p>
      </gl-card>
    </div>
  </gl-card>
</template>
