<script>
import { s__, __ } from '~/locale';
import DashboardLayout from '~/vue_shared/components/customizable_dashboard/dashboard_layout.vue';
import PanelsBase from '~/vue_shared/components/customizable_dashboard/panels_base.vue';
import VulnerabilitiesOverTimeChart from 'ee/security_dashboard/components/shared/charts/open_vulnerabilities_over_time.vue';

const tempMockData = [
  {
    name: s__('severity|Critical'),
    data: [
      ['2025-04-17', 5],
      ['2025-04-18', 5],
      ['2025-04-19', 7],
      ['2025-04-20', 7],
      ['2025-04-21', 6],
      ['2025-04-22', 8],
      ['2025-04-23', 10],
      ['2025-04-24', 10],
      ['2025-04-25', 12],
      ['2025-04-26', 11],
    ],
  },
  {
    name: s__('severity|High'),
    data: [
      ['2025-04-17', 25],
      ['2025-04-18', 27],
      ['2025-04-19', 30],
      ['2025-04-20', 30],
      ['2025-04-21', 28],
      ['2025-04-22', 31],
      ['2025-04-23', 35],
      ['2025-04-24', 35],
      ['2025-04-25', 38],
      ['2025-04-26', 36],
    ],
  },
  {
    name: s__('severity|Medium'),
    data: [
      ['2025-04-17', 45],
      ['2025-04-18', 47],
      ['2025-04-19', 50],
      ['2025-04-20', 52],
      ['2025-04-21', 48],
      ['2025-04-22', 51],
      ['2025-04-23', 55],
      ['2025-04-24', 55],
      ['2025-04-25', 58],
      ['2025-04-26', 56],
    ],
  },
  {
    name: s__('severity|Low'),
    data: [
      ['2025-04-17', 65],
      ['2025-04-18', 68],
      ['2025-04-19', 72],
      ['2025-04-20', 72],
      ['2025-04-21', 69],
      ['2025-04-22', 73],
      ['2025-04-23', 78],
      ['2025-04-24', 78],
      ['2025-04-25', 82],
      ['2025-04-26', 79],
    ],
  },
  {
    name: s__('severity|Info'),
    data: [
      ['2025-04-17', 12],
      ['2025-04-18', 15],
      ['2025-04-19', 15],
      ['2025-04-20', 18],
      ['2025-04-21', 18],
      ['2025-04-22', 16],
      ['2025-04-23', 19],
      ['2025-04-24', 19],
      ['2025-04-25', 22],
      ['2025-04-26', 22],
    ],
  },
  {
    name: s__('severity|Unknown'),
    data: [
      ['2025-04-17', 8],
      ['2025-04-18', 8],
      ['2025-04-19', 10],
      ['2025-04-20', 10],
      ['2025-04-21', 9],
      ['2025-04-22', 9],
      ['2025-04-23', 12],
      ['2025-04-24', 12],
      ['2025-04-25', 11],
      ['2025-04-26', 11],
    ],
  },
];

export default {
  components: {
    DashboardLayout,
    PanelsBase,
    VulnerabilitiesOverTimeChart,
  },
  data() {
    return {
      dashboard: {
        title: s__('SecurityReports|Security dashboard'),
        description: s__(
          // Note: This is just a placeholder text and will be replaced with the final copy, once it is ready
          'SecurityReports|This dashboard provides an overview of your security vulnerabilities.',
        ),
        panels: [
          {
            id: '1',
            title: __('Vulnerabilities over time'),
            tooltip: {
              // Note: This is just a placeholder text and will be replaced with the final copy, once it is ready
              description: __('Vulnerabilities over time'),
            },
            component: VulnerabilitiesOverTimeChart,
            componentProps: {
              chartSeries: tempMockData,
            },
            gridAttributes: {
              width: 7,
              height: 4,
              yPos: 0,
              xPos: 0,
            },
          },
        ],
      },
    };
  },
};
</script>

<template>
  <dashboard-layout :config="dashboard" data-testid="security-dashboard-new">
    <template #panel="{ panel }">
      <panels-base v-bind="panel">
        <template #body>
          <component
            :is="panel.component"
            class="gl-h-full gl-overflow-hidden"
            v-bind="panel.componentProps"
          />
        </template>
      </panels-base>
    </template>
  </dashboard-layout>
</template>
