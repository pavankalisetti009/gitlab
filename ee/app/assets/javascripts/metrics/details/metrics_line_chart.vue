<script>
import { GlLineChart, GlChartSeriesLabel } from '@gitlab/ui/dist/charts';
import { s__ } from '~/locale';
import { formatDate, convertNanoToMs } from '~/lib/utils/datetime_utility';
import { SHORT_DATE_TIME_FORMAT } from '~/observability/constants';

const SYMBOL_SIZE_DEFAULT = 5;
const SYMBOL_SIZE_HIGHLIGHTED = 10;
export default {
  components: {
    GlLineChart,
    GlChartSeriesLabel,
  },
  i18n: {
    xAxisTitle: s__('ObservabilityMetrics|Date'),
    yAxisTitle: s__('ObservabilityMetrics|Value'),
    cancelledText: s__('ObservabilityMetrics|Metrics search has been cancelled.'),
  },
  props: {
    metricData: {
      type: Array,
      required: true,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    cancelled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      tooltipTitle: '',
      tooltipContent: [],
    };
  },
  computed: {
    chartData() {
      return this.metricData.map((metric) => {
        const data = metric.values.map((value) => [
          // note date timestamps are in nano, so converting them to ms here
          convertNanoToMs(value[0]),
          parseFloat(value[1]),
          { ...metric.attributes },
          { traceIds: value[2] || [] },
        ]);
        const hasTraces = (datapointData) => datapointData[3]?.traceIds?.length > 0;

        return {
          name: Object.entries(metric.attributes)
            .map(([k, v]) => `${k}: ${v}`)
            .join(', '),
          data,
          // https://echarts.apache.org/en/option.html#series-line.symbolSize
          symbolSize: (_, p) => (hasTraces(p.data) ? SYMBOL_SIZE_HIGHLIGHTED : SYMBOL_SIZE_DEFAULT),
        };
      });
    },
    chartOption() {
      const yUnit = this.metricData?.[0]?.unit;
      const yAxisTitle = this.$options.i18n.yAxisTitle + (yUnit ? ` (${yUnit})` : '');
      return {
        dataZoom: [
          {
            type: 'slider',
          },
        ],
        xAxis: {
          type: 'time',
          name: this.$options.i18n.xAxisTitle,
        },
        yAxis: {
          name: yAxisTitle,
        },
      };
    },
  },
  methods: {
    formatTooltipText({ seriesData }) {
      // reset the tooltip
      this.tooltipTitle = '';
      this.tooltipContent = [];

      if (!Array.isArray(seriesData) || seriesData.length === 0) return;

      if (Array.isArray(seriesData[0].data)) {
        const [dateTime] = seriesData[0].data;
        this.tooltipTitle = formatDate(dateTime, SHORT_DATE_TIME_FORMAT);
      }

      this.tooltipContent = seriesData.map(({ seriesName, color, seriesId, data }) => {
        const [, metric, attr] = data;
        return {
          seriesId,
          label: seriesName,
          attributes: Object.entries(attr).map(([k, v]) => ({ key: k, value: v })),
          value: parseFloat(metric).toFixed(3),
          color,
        };
      });
    },
    chartItemClicked({ chart, params: { data } }) {
      const xValue = data[0];
      const visibleSeriesIndices = chart.getModel().getCurrentSeriesIndices();
      const datapoints =
        chart
          .getModel()
          .getSeries()
          .filter((_, index) => visibleSeriesIndices.includes(index))
          .map((series) => {
            const datapoint = series.option.data.find((point) => point[0] === xValue);
            if (datapoint) {
              return {
                seriesName: series.name,
                color: series.option.itemStyle.color,
                timestamp: datapoint[0],
                value: datapoint[1],
                traceIds: datapoint[3]?.traceIds || [],
              };
            }
            return undefined;
          })
          .filter(Boolean) || [];

      this.$emit('selected', datapoints);
    },
  },
};
</script>

<template>
  <div class="gl-relative">
    <gl-line-chart
      disabled
      :class="['gl-mb-7', { 'gl-opacity-3': loading || cancelled }]"
      :option="chartOption"
      :data="chartData"
      responsive
      :format-tooltip-text="formatTooltipText"
      @chartItemClicked="chartItemClicked"
    >
      <template #tooltip-title>
        <div data-testid="metric-tooltip-title">{{ tooltipTitle }}</div>
      </template>

      <template #tooltip-content>
        <div
          v-for="(metric, index) in tooltipContent"
          :key="`${metric.seriesId}_${index}`"
          data-testid="metric-tooltip-content"
          class="gl-mb-1 gl-flex gl-justify-between gl-text-sm"
        >
          <gl-chart-series-label :color="metric.color" class="gl-mr-7 gl-leading-normal">
            <div v-for="attr in metric.attributes" :key="attr.key + attr.value">
              <span class="gl-font-bold">{{ attr.key }}: </span>{{ attr.value }}
            </div>
          </gl-chart-series-label>

          <div data-testid="metric-tooltip-value" class="gl-font-bold">
            {{ metric.value }}
          </div>
        </div>
      </template>
    </gl-line-chart>

    <div
      v-if="cancelled"
      class="gl-absolute gl-bottom-0 gl-left-0 gl-right-0 gl-top-0 gl-py-13 gl-text-center gl-text-lg gl-font-bold"
    >
      <span>{{ $options.i18n.cancelledText }}</span>
    </div>
  </div>
</template>

<style>
.chart-cancelled-text {
  padding-top: 30%;
}
</style>
