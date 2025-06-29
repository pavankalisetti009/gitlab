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
    chartConfig() {
      const { textColor, blueDataColor, orangeDataColor, magentaDataColor } = getColors(
        this.colorScheme,
      );

      const data = [
        this.generateDataEntry({
          field: 'passed',
          color: blueDataColor,
          message: s__('Compliance report|%{percent}%% passed'),
        }),
        this.generateDataEntry({
          field: 'pending',
          color: magentaDataColor,
          message: s__('Compliance report|%{percent}%% pending'),
        }),
        this.generateDataEntry({
          field: 'failed',
          color: orangeDataColor,
          message: s__('Compliance report|%{percent}%% failed'),
        }),
      ].filter(Boolean);

      return {
        legend: {
          data: data.map((e) => e.name),
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
            data,
          },
        ],
      };
    },
  },
  methods: {
    getTooltip({ field, message }) {
      return `<div class="gl-text-default gl-text-sm gl-bg-default gl-p-3">
        <h4 class="gl-font-bold gl-text-sm gl-m-0 gl-mb-2">${sprintf(message, {
          percent: this.percentages[field],
        })} (${sprintf(this.itemFormatter(this.data[field]), { count: this.data[field] })})</h4>
        <p class="gl-font-bold gl-mt-2 gl-mb-0">${s__('Compliance report|Click to check all requirements')}</p>
      </div>`;
    },

    generateDataEntry({ message, field, color }) {
      const count = this.data[field];
      const percent = this.percentages[field];
      const name = this.legend[field];

      if (count === 0) {
        return null;
      }

      const { textColor } = getColors(this.colorScheme);
      return {
        value: count,
        field,
        message,
        name,
        itemStyle: { color },
        label: {
          show: true,
          position: 'outside',
          formatter: [
            sprintf(message, {
              percent,
            }),
            sprintf(this.itemFormatter(count), { count }),
          ].join('\n'),
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
