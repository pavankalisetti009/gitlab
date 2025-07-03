<script>
import { GlChart } from '@gitlab/ui/dist/charts';
import { s__, sprintf } from '~/locale';
import { getColors, getLegendConfig, getTooltipConfig } from '../utils/chart';

function distributePercentages(values, total) {
  const exactPercentages = values.map((value) => (value / total) * 100);
  const floors = exactPercentages.map((p) => Math.floor(p));
  const remainders = exactPercentages.map((p, i) => ({
    index: i,
    remainder: p - floors[i],
  }));
  remainders.sort((a, b) => b.remainder - a.remainder);

  const result = [...floors];
  const totalFloors = floors.reduce((sum, f) => sum + f, 0);
  const remainingPercentage = 100 - totalFloors;

  for (let i = 0; i < remainingPercentage; i += 1) {
    result[remainders[i].index] += 1;
  }

  return result;
}

const COMPLIANCE_FIELDS = ['passed', 'pending', 'failed'];
const CHART_COLORS = {
  passed: 'blueDataColor',
  pending: 'magentaDataColor',
  failed: 'orangeDataColor',
};

export default {
  components: {
    GlChart,
  },
  props: {
    colorScheme: {
      type: String,
      required: true,
    },
    legend: {
      type: Object,
      required: true,
    },
    data: {
      type: Object,
      required: true,
    },
    itemFormatter: {
      type: Function,
      required: true,
    },
    path: {
      type: String,
      required: true,
    },
  },
  computed: {
    percentages() {
      const total = this.data.passed + this.data.pending + this.data.failed;
      const values = [this.data.passed, this.data.pending, this.data.failed];
      const [passedPct, pendingPct, failedPct] = distributePercentages(values, total);

      return {
        passed: passedPct,
        pending: pendingPct,
        failed: failedPct,
      };
    },
    colors() {
      return getColors(this.colorScheme);
    },
    chartData() {
      return COMPLIANCE_FIELDS.map((field) =>
        this.generateDataEntry({
          field,
          color: this.colors[CHART_COLORS[field]],
          message: this.getFieldMessage(field),
        }),
      ).filter(Boolean);
    },
    chartConfig() {
      const { textColor } = this.colors;

      return {
        legend: {
          data: this.chartData.map((e) => e.name),
          ...getLegendConfig(textColor),
        },
        tooltip: {
          show: true,
          trigger: 'item',
          ...getTooltipConfig(textColor),
          formatter: (params) =>
            this.getTooltip({
              field: params.data.field,
              message: params.data.message,
            }),
        },
        series: [
          {
            type: 'pie',
            radius: ['0%', '60%'],
            center: ['50%', '60%'],
            startAngle: 0,
            data: this.chartData,
          },
        ],
      };
    },
  },
  methods: {
    getFieldMessage(field) {
      const messages = {
        passed: s__('Compliance report|%{percent}%% passed'),
        pending: s__('Compliance report|%{percent}%% pending'),
        failed: s__('Compliance report|%{percent}%% failed'),
      };
      return messages[field];
    },
    getTooltip({ field, message }) {
      const percentText = sprintf(message, { percent: this.percentages[field] });
      const countText = sprintf(this.itemFormatter(this.data[field]), { count: this.data[field] });

      return `
    <div class="gl-text-default gl-text-sm gl-bg-default gl-p-3">
      <div class="gl-font-bold gl-text-sm gl-mb-2">
        ${percentText} (${countText})
      </div>
      <div class="gl-font-bold gl-mt-2">
        ${s__('Compliance report|Click to check all requirements')}
      </div>
    </div>
  `;
    },
    formatLabel({ message, percent, count }) {
      return [sprintf(message, { percent }), sprintf(this.itemFormatter(count), { count })].join(
        '\n',
      );
    },

    generateDataEntry({ message, field, color }) {
      const count = this.data[field];
      const percent = this.percentages[field];
      const name = this.legend[field];

      if (count === 0) {
        return null;
      }

      const { textColor } = this.colors;
      return {
        value: count,
        field,
        message,
        name,
        itemStyle: { color },
        label: {
          show: true,
          position: 'outside',
          formatter: this.formatLabel({ message, percent, count }),
          fontSize: 12,
          fontWeight: 'bold',
          color: textColor,
        },
        labelLine: {
          show: false,
        },
      };
    },

    handleChartClick() {
      this.$router.push({ name: this.path });
    },
  },
};
</script>

<template>
  <gl-chart height="auto" :options="chartConfig" @chartItemClicked="handleChartClick" />
</template>
