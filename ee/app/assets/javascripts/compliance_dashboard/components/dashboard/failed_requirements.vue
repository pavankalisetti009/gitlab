<script>
import { GlEmptyState } from '@gitlab/ui';
import { s__ } from '~/locale';

import { ROUTE_STANDARDS_ADHERENCE } from '../../constants';
import StatusChart from './components/status_chart.vue';

export default {
  components: {
    GlEmptyState,
    StatusChart,
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
      const { passed, failed, pending } = this.failedRequirements;
      return passed + failed + pending === 0;
    },
  },
  legend: {
    passed: s__('Compliance report|Passed'),
    failed: s__('Compliance report|Failed'),
    pending: s__('Compliance report|Pending'),
  },
  ROUTE_STANDARDS_ADHERENCE,
};
</script>

<template>
  <status-chart
    v-if="!isEmpty"
    :legend="$options.legend"
    :color-scheme="colorScheme"
    :x-axis-title="s__('Compliance report|Requirements')"
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
