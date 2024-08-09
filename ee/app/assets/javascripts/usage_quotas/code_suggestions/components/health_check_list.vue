<script>
import {
  GlAlert,
  GlBadge,
  GlCard,
  GlLoadingIcon,
  GlSkeletonLoader,
  GlExperimentBadge,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import getCloudConnectorHealthStatus from 'ee/usage_quotas/add_on/graphql/cloud_connector_health_check.query.graphql';

export default {
  name: 'HealthCheckList',
  components: {
    GlAlert,
    GlBadge,
    GlCard,
    GlLoadingIcon,
    GlSkeletonLoader,
    GlExperimentBadge,
  },
  data() {
    return {
      healthStatus: null,
      probes: [],
      isLoading: false,
    };
  },
  computed: {
    hasProbes() {
      return this.probes.length > 0;
    },
    shouldBeShown() {
      return this.hasProbes || this.isLoading;
    },
  },
  methods: {
    getVariantForProbe(probe) {
      return probe.success ? 'success' : 'danger';
    },
    async runHealthCheck() {
      this.probes = [];
      this.isLoading = true;
      try {
        const { data } = await this.$apollo.query({
          query: getCloudConnectorHealthStatus,
        });
        this.healthStatus = data?.cloudConnectorStatus?.success || false;
        this.probes = data?.cloudConnectorStatus?.probeResults || [];
      } catch (error) {
        this.healthStatus = false;
        this.probes = [];
      } finally {
        this.isLoading = false;
        this.$emit('health-check-completed');
      }
    },
  },
  i18n: {
    healthCheckTitle: s__('UsageQuotas|Health check results'),
    healthCheckSucceeded: s__('UsageQuotas|GitLab Duo should be operational.'),
    healthCheckFailed: s__('UsageQuotas|Not operational. Resolve issues to use GitLab Duo.'),
    healthUp: s__('UsageQuotas|Passed'),
    healthDown: s__('UsageQuotas|Failed'),
    loadingTests: s__('UsageQuotas|Tests are running...'),
  },
};
</script>
<template>
  <gl-card
    v-if="shouldBeShown"
    class="gl-new-card gl-mb-5"
    header-class="gl-new-card-header"
    body-class="gl-new-card-body gl-px-0"
  >
    <template #header>
      <strong>{{ $options.i18n.healthCheckTitle }}</strong>
      <gl-experiment-badge type="beta" />
    </template>

    <template #default>
      <div v-if="isLoading" class="gl-px-3 gl-py-5">
        <gl-skeleton-loader :width="1248" :height="232">
          <rect x="8" y="0" width="24" height="24" rx="16" />
          <rect x="48" y="4" width="247" height="16" rx="4" />

          <rect x="8" y="52" width="24" height="24" rx="16" />
          <rect x="48" y="56" width="185" height="16" rx="4" />

          <rect x="8" y="104" width="24" height="24" rx="16" />
          <rect x="48" y="108" width="311" height="16" rx="4" />

          <rect x="8" y="156" width="24" height="24" rx="16" />
          <rect x="48" y="160" width="167" height="16" rx="4" />

          <rect x="8" y="208" width="24" height="24" rx="16" />
          <rect x="48" y="212" width="227" height="16" rx="4" />
        </gl-skeleton-loader>
      </div>
      <div v-else>
        <gl-alert
          v-for="(probe, i) in probes"
          :key="`probe.name-${i}`"
          :dismissible="false"
          :variant="getVariantForProbe(probe)"
          class="gl-font-monospace"
        >
          {{ probe.message }}
        </gl-alert>
      </div>
    </template>

    <template #footer>
      <div v-if="isLoading" class="gl-flex gl-items-center gl-gap-3">
        <gl-loading-icon size="sm" />
        <span>{{ $options.i18n.loadingTests }}</span>
      </div>
      <div v-else-if="healthStatus" class="gl-flex gl-items-center gl-gap-3">
        <gl-badge variant="success">{{ $options.i18n.healthUp }}</gl-badge>
        <span>{{ $options.i18n.healthCheckSucceeded }}</span>
      </div>
      <div v-else class="gl-flex gl-items-center gl-gap-3">
        <gl-badge variant="danger">{{ $options.i18n.healthDown }}</gl-badge>
        <span>{{ $options.i18n.healthCheckFailed }}</span>
      </div>
    </template>
  </gl-card>
</template>
