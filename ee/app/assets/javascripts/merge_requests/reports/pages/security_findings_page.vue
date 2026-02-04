<script>
import { s__ } from '~/locale';
import SmartInterval from '~/smart_interval';
import enabledScansQuery from 'ee/vue_merge_request_widget/queries/enabled_scans.query.graphql';

const POLL_INTERVAL = 3000;

export default {
  name: 'SecurityFindingsPage',
  props: {
    mr: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      enabledScans: {
        full: {},
        partial: {},
      },
      errorMessage: '',
    };
  },
  apollo: {
    enabledScans: {
      query: enabledScansQuery,
      variables() {
        return {
          fullPath: this.targetProjectFullPath,
          pipelineIid: this.pipelineIid,
        };
      },
      update({ project }) {
        if (!project?.pipeline) {
          return { full: {}, partial: {} };
        }

        const scans = project.pipeline;
        const isReady = scans.enabledSecurityScans?.ready === true;

        if (!isReady && !this.$options.pollingInterval) {
          this.initPolling();
        }

        if (isReady && this.$options.pollingInterval) {
          this.$options.pollingInterval.destroy();
          this.$options.pollingInterval = undefined;
        }

        return {
          full: scans.enabledSecurityScans || {},
          partial: scans.enabledPartialSecurityScans || {},
        };
      },
      error() {
        this.errorMessage = s__(
          'ciReport|Error while fetching enabled scans. Please try again later.',
        );
      },
      skip() {
        return !this.pipelineIid || !this.targetProjectFullPath;
      },
    },
  },
  computed: {
    pipelineIid() {
      return this.mr.pipeline?.iid;
    },
    targetProjectFullPath() {
      return this.mr.targetProjectFullPath;
    },
    isLoading() {
      return this.$apollo.queries.enabledScans.loading;
    },
    hasEnabledScans() {
      const isEnabled = (scans) =>
        Object.entries(scans)
          .filter(([key]) => key !== 'ready' && key !== '__typename')
          .some(([, value]) => value === true);

      return isEnabled(this.enabledScans.full) || isEnabled(this.enabledScans.partial);
    },
  },
  beforeDestroy() {
    if (this.$options.pollingInterval) {
      this.$options.pollingInterval.destroy();
    }
  },
  methods: {
    initPolling() {
      this.$options.pollingInterval = new SmartInterval({
        callback: () => this.$apollo.queries.enabledScans.refetch(),
        startingInterval: POLL_INTERVAL,
        incrementByFactorOf: 1,
        immediateExecution: true,
      });
    },
  },
  pollingInterval: undefined,
};
</script>

<template>
  <div data-testid="security-findings-page">
    <template v-if="errorMessage">
      {{ errorMessage }}
    </template>
    <template v-else-if="isLoading">
      {{ isLoading }}
    </template>
    <template v-else>{{ hasEnabledScans }} {{ enabledScans.full.ready }}</template>
  </div>
</template>
