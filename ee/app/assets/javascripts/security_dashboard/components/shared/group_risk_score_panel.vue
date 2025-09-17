<script>
import { GlDashboardPanel } from '@gitlab/ui';
import groupTotalRiskScore from 'ee/security_dashboard/graphql/queries/group_total_risk_score.query.graphql';
import TotalRiskScore from './charts/total_risk_score.vue';
import RiskScoreByProject from './charts/risk_score_by_project.vue';
import RiskScoreGroupBy from './risk_score_group_by.vue';
import RiskScoreTooltip from './risk_score_tooltip.vue';

export default {
  name: 'GroupRiskScorePanel',
  components: {
    GlDashboardPanel,
    TotalRiskScore,
    RiskScoreByProject,
    RiskScoreGroupBy,
    RiskScoreTooltip,
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
      vulnerabilitiesAverageScore: 0,
      projects: [],
      hasFetchError: false,
      groupedBy: 'default',
    };
  },
  apollo: {
    riskScore: {
      query: groupTotalRiskScore,
      variables() {
        return {
          fullPath: this.groupFullPath,
          projectId: this.filters.projectId,
          includeByDefault: this.groupedBy === 'default',
          includeByProject: this.groupedBy === 'project',
        };
      },
      update(data) {
        return data?.group?.securityMetrics?.riskScore?.score || 0;
      },
      result({ data }) {
        const { factors, byProject } = data?.group?.securityMetrics?.riskScore || {};

        this.vulnerabilitiesAverageScore = factors?.vulnerabilitiesAverageScore?.factor || 0;

        const projectNodes = [...(byProject?.nodes || [])];
        projectNodes.sort((a, b) => b.score - a.score);
        this.projects = projectNodes;
      },
      error() {
        this.hasFetchError = true;
      },
    },
  },
};
</script>

<template>
  <gl-dashboard-panel
    :title="s__('SecurityReports|Risk score')"
    :loading="$apollo.queries.riskScore.loading"
    :border-color-class="hasFetchError ? 'gl-border-t-red-500' : ''"
    :title-icon="hasFetchError ? 'error' : ''"
    :title-icon-class="hasFetchError ? 'gl-text-red-500' : ''"
  >
    <template #info-popover-title>{{ s__('SecurityReports|Risk score') }}</template>
    <template #info-popover-content>
      <risk-score-tooltip
        :vulnerabilities-average-score-factor="vulnerabilitiesAverageScore"
        :is-loading="$apollo.queries.riskScore.loading"
      />
    </template>
    <template #filters>
      <risk-score-group-by v-model="groupedBy" />
    </template>
    <template v-if="!hasFetchError" #body>
      <total-risk-score v-if="groupedBy === 'default'" :score="riskScore" />
      <risk-score-by-project v-else :risk-scores="projects" class="gl-pt-3" />
    </template>
    <template v-else #alert-message>
      <p>{{ __('Something went wrong. Please try again.') }}</p>
    </template>
  </gl-dashboard-panel>
</template>
