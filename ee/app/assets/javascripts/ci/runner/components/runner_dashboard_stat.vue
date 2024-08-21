<script>
import { formatNumber } from '~/locale';
import { INSTANCE_TYPE, GROUP_TYPE } from '~/ci/runner/constants';
import RunnerCount from '~/ci/runner/components/stat/runner_count.vue';

export default {
  name: 'RunnerDashboardStat',
  components: {
    RunnerCount,
  },
  props: {
    scope: {
      type: String,
      required: true,
      validator: (val) => [INSTANCE_TYPE, GROUP_TYPE].includes(val),
    },
    variables: {
      type: Object,
      required: true,
    },
  },
  methods: {
    formattedValue(value) {
      if (typeof value === 'number') {
        return formatNumber(value);
      }
      return '-';
    },
  },
  INSTANCE_TYPE,
};
</script>

<template>
  <div class="gl-border gl-rounded-base gl-p-5">
    <h2 class="gl-mt-0 gl-text-lg">
      <slot name="title"></slot>
    </h2>
    <runner-count #default="{ count }" :scope="scope" :variables="variables">
      <span class="gl-text-size-h-display gl-font-bold">{{ formattedValue(count) }}</span>
    </runner-count>
  </div>
</template>
