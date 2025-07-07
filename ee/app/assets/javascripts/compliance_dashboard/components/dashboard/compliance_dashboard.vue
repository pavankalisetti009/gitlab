<script>
import { __, s__ } from '~/locale';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

import DashboardLayout from '~/vue_shared/components/customizable_dashboard/dashboard_layout.vue';
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';

import { isTopLevelGroup } from '../../utils';
import FrameworkCoverage from './framework_coverage.vue';
import frameworkCoverageQuery from './graphql/framework_coverage.query.graphql';

const MINIMAL_HEIGHT = 2;
const FRAMEWORKS_PER_UNIT = 7;
const DummyComponent = {
  render() {
    return null;
  },
};

export default {
  components: {
    DashboardLayout,
    ExtendedDashboardPanel,
    FrameworkCoverage,
  },
  props: {
    groupPath: {
      type: String,
      required: true,
    },
    rootAncestorPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      summary: {
        totalProjects: 0,
        coveredCount: 0,
        details: [],
      },
    };
  },
  apollo: {
    summary: {
      query: frameworkCoverageQuery,
      variables() {
        return {
          groupPath: this.groupPath,
        };
      },
      update(data) {
        const { totalProjects, coveredCount } = data.group.complianceFrameworkCoverageSummary;
        const { nodes: details } = data.group.complianceFrameworksCoverageDetails;
        return {
          totalProjects,
          coveredCount,
          details,
        };
      },
      error(error) {
        createAlert({
          message: __('Something went wrong on our end.'),
        });
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    isTopLevelGroup() {
      return isTopLevelGroup(this.groupPath, this.rootAncestorPath);
    },
    dashboardConfig() {
      const coverageHeight =
        MINIMAL_HEIGHT + Math.ceil(this.summary.details.length / FRAMEWORKS_PER_UNIT);

      return {
        panels: [
          {
            id: '1',
            extendedDashboardPanelProps: {
              title: s__('ComplianceReport|Compliance framework coverage'),
              loading: this.$apollo.queries.summary.loading,
            },
            component: FrameworkCoverage,
            componentProps: {
              summary: this.summary,
              isTopLevelGroup: this.isTopLevelGroup,
            },
            gridAttributes: {
              width: 12,
              height: coverageHeight,
              yPos: 0,
              xPos: 0,
            },
          },
          {
            id: '2',
            extendedDashboardPanelProps: {
              title: s__('ComplianceReport|Failed requirements'),
            },
            component: DummyComponent,
            gridAttributes: {
              width: 6,
              height: 1,
              yPos: coverageHeight,
              xPos: 0,
            },
          },
          {
            id: '3',
            extendedDashboardPanelProps: {
              title: s__('ComplianceReport|Failed controls'),
            },
            component: DummyComponent,
            gridAttributes: {
              width: 6,
              height: 1,
              yPos: coverageHeight,
              xPos: 6,
            },
          },
          {
            id: '4',
            extendedDashboardPanelProps: {
              title: s__('ComplianceReport|Frameworks needs attention'),
            },
            component: DummyComponent,
            gridAttributes: {
              width: 12,
              height: 1,
              yPos: 3,
              xPos: 0,
            },
          },
        ],
      };
    },
  },
};
</script>

<template>
  <dashboard-layout :config="dashboardConfig">
    <template #panel="{ panel }">
      <extended-dashboard-panel v-bind="panel.extendedDashboardPanelProps">
        <template #body>
          <component
            :is="panel.component"
            class="gl-h-full gl-overflow-hidden"
            v-bind="panel.componentProps"
          />
        </template>
      </extended-dashboard-panel>
    </template>
  </dashboard-layout>
</template>
