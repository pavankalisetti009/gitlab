<script>
import { camelCase } from 'lodash';
import { GlStackedColumnChart } from '@gitlab/ui/src/charts';
import { GRAY_500 } from '@gitlab/ui/src/tokens/build/js/tokens';
import {
  listenSystemColorSchemeChange,
  removeListenerSystemColorSchemeChange,
} from '~/lib/utils/css_utils';
import { getSeverityColors } from 'ee/security_dashboard/utils/chart_utils';
import { REPORT_TYPE_COLORS } from 'ee/security_dashboard/components/shared/vulnerability_report/constants';

export default {
  name: 'VulnerabilitiesByAgeChart',
  components: {
    GlStackedColumnChart,
  },
  props: {
    bars: {
      type: Array,
      required: true,
      validator(value) {
        return value.every(({ name, data }) => {
          // Each series must have a name (string) and data (array)
          return typeof name === 'string' && Array.isArray(data);
        });
      },
    },
    labels: {
      type: Array,
      required: true,
      default: () => [],
    },
  },
  data() {
    return {
      severityColors: {},
    };
  },
  computed: {
    customPalette() {
      return this.bars.map((bar) => {
        const normalizedId = camelCase(bar.id);
        return this.severityColors[normalizedId] || REPORT_TYPE_COLORS[normalizedId] || GRAY_500;
      });
    },
  },
  mounted() {
    this.setSeverityColors();
    listenSystemColorSchemeChange(this.setSeverityColors);
  },
  destroyed() {
    removeListenerSystemColorSchemeChange(this.setSeverityColors);
  },
  methods: {
    setSeverityColors() {
      this.severityColors = getSeverityColors();
    },
  },
  chartOptions: {
    animation: false,
    // Note: This is a workaround to remove the extra whitespace when the chart has no title
    // Once https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/issues/2199 has been fixed, this can be removed
    grid: {
      left: '10px',
      right: '10px',
      bottom: '10px',
      top: '10px',
      // Setting `containLabel` to `true` ensures the grid area is large enough to contain the labels
      containLabel: true,
    },
  },
};
</script>

<template>
  <gl-stacked-column-chart
    :bars="bars"
    :option="$options.chartOptions"
    :group-by="labels"
    :custom-palette="customPalette"
    :include-legend-avg-max="false"
    presentation="stacked"
    x-axis-type="category"
    :x-axis-title="''"
    :y-axis-title="''"
    responsive
    height="auto"
  />
</template>
