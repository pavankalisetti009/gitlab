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
    failedRequirements: {
      type: Object,
      required: true,
    },
  },
  computed: {
    isEmpty() {
      return (
        this.failedRequirements.passed +
          this.failedRequirements.failed +
          this.failedRequirements.pending ===
        0
      );
    },
  },
  legend: {
    passed: s__('Compliance report|Successful requirements'),
    failed: s__('Compliance report|Failed requirements'),
    pending: s__('Compliance report|Pending requirements'),
  },
  itemFormatter: (count) =>
    n__('Compliance report|%{count} requirement', 'Compliance report|%{count} requirements', count),
  ROUTE_STANDARDS_ADHERENCE,
};
</script>

<template>
  <pie-chart
    v-if="!isEmpty"
    :legend="$options.legend"
    :color-scheme="colorScheme"
    :item-formatter="$options.itemFormatter"
    :data="failedRequirements"
    :path="$options.ROUTE_STANDARDS_ADHERENCE"
  />
  <gl-empty-state
    v-else
    :title="s__('Compliance report|There are no requirements.')"
    :description="
      s__('Compliance report|You can add requirements inside the compliance framework.')
    "
    class="gl-m-0 gl-pt-3"
  />
</template>
