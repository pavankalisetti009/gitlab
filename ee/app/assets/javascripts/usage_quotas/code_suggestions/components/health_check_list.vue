<script>
import { GlAlert } from '@gitlab/ui';
import { s__ } from '~/locale';
import getCloudConnectorHealthStatus from 'ee/usage_quotas/add_on/graphql/cloud_connector_health_check.query.graphql';

export default {
  name: 'HealthCheckList',
  components: {
    GlAlert,
  },
  props: {
    cloudConnectorStatus: {
      type: Object,
      required: false,
      default: () => {},
    },
  },
  data() {
    return {
      healthStatus: null,
      probes: [],
    };
  },
  apollo: {
    healthStatusCheck: {
      query: getCloudConnectorHealthStatus,
      update(data) {
        this.healthStatus = data?.cloudConnectorStatus?.success || false;
        this.probes = data?.cloudConnectorStatus?.probeResults || [];
      },
    },
  },
  methods: {
    getVariantForProbe(probe) {
      return probe.success ? 'success' : 'danger';
    },
  },
  i18n: {
    healthCheckFailed: s__('UsageQuotas|Health check failed'),
    healthCheckSucceeded: s__('UsageQuotas|Health check succeeded'),
  },
};
</script>
<template>
  <section>
    <header>
      <h1 class="gl-text-size-h2">
        <span v-if="healthStatus">{{ $options.i18n.healthCheckSucceeded }}</span>
        <span v-else>{{ $options.i18n.healthCheckFailed }}</span>
      </h1>
    </header>

    <gl-alert
      v-for="(probe, i) in probes"
      :key="`probe.name-${i}`"
      :variant="getVariantForProbe(probe)"
      class="gl-mb-3"
    >
      {{ probe.message }}
    </gl-alert>
  </section>
</template>
