<script>
import { GlDashboardPanel, GlBadge, GlTooltipDirective } from '@gitlab/ui';
import { sprintf, s__ } from '~/locale';
import { readFromUrl, writeToUrl } from 'ee/security_dashboard/utils/panel_state_url_sync';
import groupTotalRiskScore from 'ee/security_dashboard/graphql/queries/group_total_risk_score.query.graphql';
import TotalRiskScore from './charts/total_risk_score.vue';
import RiskScoreByProject from './charts/risk_score_by_project.vue';
import RiskScoreGroupBy from './risk_score_group_by.vue';
import RiskScoreTooltip from './risk_score_tooltip.vue';

const PANEL_ID = 'riskScore';
const GROUP_BY_PARAM_NAME = 'groupBy';
const GROUP_BY_DEFAULT = 'default';
const GROUP_BY_PROJECT = 'project';

export default {
  name: 'GroupRiskScorePanel',
  components: {
    GlDashboardPanel,
    GlBadge,
    TotalRiskScore,
    RiskScoreByProject,
    RiskScoreGroupBy,
    RiskScoreTooltip,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
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
      hasFetchError: false,
      groupedBy: readFromUrl({
        panelId: PANEL_ID,
        paramName: GROUP_BY_PARAM_NAME,
        defaultValue: GROUP_BY_DEFAULT,
      }),
      isOverProjectCountThreshold: false,
    };
  },
  apollo: {
    riskScore: {
      query: groupTotalRiskScore,
      variables() {
        return {
          fullPath: this.groupFullPath,
          projectId: this.filters.projectId,
          includeByDefault: this.groupedBy === GROUP_BY_DEFAULT,
          includeByProject: this.groupedBy === GROUP_BY_PROJECT,
          projectCount: this.$options.projectCountThreshold,
        };
      },
      update(data) {
        return data?.group?.securityMetrics?.riskScore?.score || 0;
      },
      result({ data }) {
        const { byProject } = data?.group?.securityMetrics?.riskScore || {};

        const projectNodes = [...(byProject?.nodes || [])];
        projectNodes.sort((a, b) => b.score - a.score);
        this.projects = projectNodes;

        this.isOverProjectCountThreshold = byProject?.pageInfo?.hasNextPage || false;
      },
      error() {
        this.hasFetchError = true;
      },
    },
  },
  computed: {
    shouldShowMaxProjectsBadge() {
      return this.groupedBy === GROUP_BY_PROJECT && this.isOverProjectCountThreshold;
    },
    maxProjectsTooltipTitle() {
      return sprintf(
        s__(
          'SecurityReports|Only %{count} projects with the highest risk scores are shown. Use the filter at the top of the dashboard to narrow down your results.',
        ),
        { count: this.$options.projectCountThreshold },
      );
    },
  },
  watch: {
    groupedBy(value) {
      writeToUrl({
        panelId: PANEL_ID,
        paramName: GROUP_BY_PARAM_NAME,
        value,
        defaultValue: GROUP_BY_DEFAULT,
      });
    },
  },
  projectCountThreshold: 96,
};
</script>

<template>
  <gl-dashboard-panel
    :title="s__('SecurityReports|Risk score')"
    :loading="$apollo.queries.riskScore.loading"
    :border-color-class="hasFetchError ? 'gl-border-t-red-500' : ''"
    :title-icon="hasFetchError ? 'error' : ''"
    :title-icon-class="hasFetchError ? 'gl-text-red-500' : ''"
    :title-popover-classes="['gl-min-w-fit']"
  >
    <template #info-popover-title>{{ s__('SecurityReports|Risk score formula') }}</template>
    <template #info-popover-content>
      <risk-score-tooltip />
    </template>
    <template #filters>
      <gl-badge
        v-if="shouldShowMaxProjectsBadge"
        v-gl-tooltip
        variant="neutral"
        class="gl-mr-3"
        :title="maxProjectsTooltipTitle"
      >
        {{ s__('SecurityReports|Max project limit reached') }}
      </gl-badge>
      <risk-score-group-by v-model="groupedBy" />
    </template>
    <template #body>
      <template v-if="!hasFetchError">
        <total-risk-score v-if="groupedBy === 'default'" :score="riskScore" />
        <risk-score-by-project v-else :risk-scores="projects" class="gl-pt-3" />
      </template>
      <template v-else>
        <p class="gl-m-0 gl-flex gl-h-full gl-w-full gl-items-center gl-justify-center gl-p-0">
          {{ __('Something went wrong. Please try again.') }}
        </p>
      </template>
    </template>
  </gl-dashboard-panel>
</template>
