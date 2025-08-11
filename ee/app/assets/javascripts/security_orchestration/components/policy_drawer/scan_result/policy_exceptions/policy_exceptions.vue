<script>
import { s__, __, n__, sprintf } from '~/locale';
import BranchPatternException from './branch_pattern_exception.vue';

export default {
  i18n: {
    header: s__('SecurityOrchestration|Policy Bypass Options'),
  },
  name: 'PolicyExceptions',
  components: {
    BranchPatternException,
  },
  props: {
    exceptions: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    branches() {
      return this.exceptions.branches || [];
    },
    hasBranches() {
      return this.branches.length > 0;
    },
    totalExceptionsCount() {
      let sum = 0;

      Object.values(this.exceptions).forEach((exceptions) => {
        const length = Array.isArray(exceptions) ? exceptions.length : 0;
        sum += length;
      });

      return sum;
    },
    subHeaderText() {
      const configurations = n__('configuration', 'configurations', this.totalExceptionsCount);

      return sprintf(__('%{count} bypass %{configurations} defined:'), {
        configurations,
        count: this.totalExceptionsCount,
      });
    },
  },
};
</script>

<template>
  <div>
    <h5 data-testid="header">{{ $options.i18n.header }}</h5>
    <p v-if="totalExceptionsCount" data-testid="subheader" class="gl-mb-2">{{ subHeaderText }}</p>

    <branch-pattern-exception v-if="hasBranches" :branches="branches" />
  </div>
</template>
