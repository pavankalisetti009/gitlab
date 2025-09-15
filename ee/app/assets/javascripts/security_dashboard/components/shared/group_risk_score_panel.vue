<script>
import { GlDashboardPanel } from '@gitlab/ui';
import groupTotalRiskScore from 'ee/security_dashboard/graphql/queries/group_total_risk_score.query.graphql';
import TotalRiskScore from './charts/total_risk_score.vue';
import RiskScoreByProject from './charts/risk_score_by_project.vue';
import RiskScoreGroupBy from './risk_score_group_by.vue';

export default {
  name: 'GroupRiskScorePanel',
  components: {
    GlDashboardPanel,
    TotalRiskScore,
    RiskScoreByProject,
    RiskScoreGroupBy,
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
      projects: [],
      fetchError: false,
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
        const riskScore = data?.group?.securityMetrics?.riskScore;
        if (!riskScore) {
          this.projects = [];
          return 0;
        }

        const projectNodes = [...(riskScore.byProject?.nodes || [])];
        projectNodes.sort((a, b) => b.score - a.score);
        this.projects = projectNodes;

        return riskScore.score || 0;
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
    <template #filters>
      <risk-score-group-by v-model="groupedBy" />
    </template>
    <template v-if="!fetchError" #body>
      <total-risk-score v-if="groupedBy === 'default'" :score="riskScore" />
      <risk-score-by-project v-else :risk-scores="projects" class="gl-pt-3" />
    </template>
    <template v-else #alert-message>
      <p>{{ __('Something went wrong. Please try again.') }}</p>
    </template>
  </gl-dashboard-panel>
</template>
