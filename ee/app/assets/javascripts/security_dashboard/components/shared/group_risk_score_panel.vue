<script>
import { GlDashboardPanel } from '@gitlab/ui';
import TotalRiskScore from 'ee/security_dashboard/components/shared/charts/total_risk_score.vue';
import groupTotalRiskScore from 'ee/security_dashboard/graphql/queries/group_total_risk_score.query.graphql';

export default {
  name: 'GroupRiskScorePanel',
  components: {
    GlDashboardPanel,
    TotalRiskScore,
  },
  inject: ['groupFullPath'],
  props: {
    filters: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      riskScore: 0,
      fetchError: false,
    };
  },
  apollo: {
    riskScore: {
      query: groupTotalRiskScore,
      variables() {
        return {
          fullPath: this.groupFullPath,
          projectId: this.filters.projectId,
        };
      },
      update(data) {
        return data.group?.securityMetrics?.riskScore?.score || 0;
      },
      error() {
        this.fetchError = true;
      },
    },
  },
};
</script>

<template>
  <gl-dashboard-panel
    :title="s__('SecurityReports|Risk score')"
    :loading="$apollo.queries.riskScore.loading"
    :border-color-class="fetchError ? 'gl-border-t-red-500' : ''"
    :title-icon="fetchError ? 'error' : ''"
    :title-icon-class="fetchError ? 'gl-text-red-500' : ''"
  >
    <template v-if="!fetchError" #body>
      <total-risk-score :score="riskScore" />
    </template>
    <template v-else #alert-message>
      <p>{{ __('Something went wrong. Please try again.') }}</p>
    </template>
  </gl-dashboard-panel>
</template>
