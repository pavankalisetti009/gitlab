<script>
import { GlEmptyState } from '@gitlab/ui';
import { s__, n__ } from '~/locale';

import { ROUTE_STANDARDS_ADHERENCE } from '../../constants';
import PieChart from './components/pie_chart.vue';

export default {
  components: {
    GlEmptyState,
    PieChart,
  },
  props: {
    colorScheme: {
      type: String,
      required: true,
    },
    failedControls: {
      type: Object,
      required: true,
    },
  },
  computed: {
    isEmpty() {
      return (
        this.failedControls.passed + this.failedControls.failed + this.failedControls.pending === 0
      );
    },
  },
  legend: {
    passed: s__('Compliance report|Successful controls'),
    failed: s__('Compliance report|Failed controls'),
    pending: s__('Compliance report|Pending controls'),
  },
  itemFormatter: (count) =>
    n__('Compliance report|%{count} control', 'Compliance report|%{count} controls', count),
  ROUTE_STANDARDS_ADHERENCE,
};
</script>

<template>
  <pie-chart
    v-if="!isEmpty"
    :legend="$options.legend"
    :color-scheme="colorScheme"
    :item-formatter="$options.itemFormatter"
    :data="failedControls"
    :path="$options.ROUTE_STANDARDS_ADHERENCE"
  />
  <gl-empty-state
    v-else
    :title="s__('Compliance report|There are no controls.')"
    :description="
      s__(
        'Compliance report|You can add controls for requirements inside the compliance framework.',
      )
    "
    class="gl-m-0 gl-pt-3"
  />
</template>
