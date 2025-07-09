<script>
import { GlEmptyState } from '@gitlab/ui';

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
    failedControls: {
      type: Object,
      required: true,
    },
  },
  computed: {
    isEmpty() {
      const { passed, failed, pending } = this.failedControls;
      return passed + failed + pending === 0;
    },
  },

  ROUTE_STANDARDS_ADHERENCE,
};
</script>

<template>
  <status-chart
    v-if="!isEmpty"
    :legend="$options.legend"
    :color-scheme="colorScheme"
    :data="failedControls"
    :x-axis-title="s__('Compliance report|Controls')"
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
