<script>
import { GlSkeletonLoader } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'RiskScoreTooltip',
  components: {
    GlSkeletonLoader,
  },
  props: {
    vulnerabilitiesAverageScoreFactor: {
      type: Number,
      required: false,
      default: null,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    riskScoreFactors() {
      return [
        {
          id: 'vulnerabilities-average-score',
          label: s__('Security Reports|Vulnerabilities average score'),
          value: this.vulnerabilitiesAverageScoreFactor,
        },
      ];
    },
  },
};
</script>

<template>
  <div>
    <dl v-for="factor in riskScoreFactors" :key="factor.label" class="gl-my-0 gl-flex gl-min-w-30">
      <dt :data-testid="`${factor.id}-label`">{{ factor.label }}</dt>
      <dd class="gl-my-0 gl-ml-auto">
        <gl-skeleton-loader v-if="isLoading" :width="30" :lines="1" />
        <span v-else :data-testid="`${factor.id}-value`">{{
          sprintf(s__('SecurityReports|%{riskFactor}x'), { riskFactor: factor.value })
        }}</span>
      </dd>
    </dl>
    <p class="gl-my-0 gl-text-gray-500" data-testid="risk-score-description">
      ({{
        s__(
          'SecurityReports|Includes Severity, Age, Exploitation status, EPSS score, Reachability, and/or Secret validity',
        )
      }})
    </p>
  </div>
</template>
