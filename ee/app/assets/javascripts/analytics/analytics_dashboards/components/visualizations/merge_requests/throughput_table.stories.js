import DashboardLayout from 'storybook_helpers/dashboards/dashboard_layout.vue';
import { INITIAL_PAGINATION_STATE } from 'ee/analytics/merge_request_analytics/constants';
import MergeRequestsThroughputTable from './throughput_table.vue';
import { throughputTableData as list } from './stories_constants';

export default {
  component: MergeRequestsThroughputTable,
  title:
    'ee/analytics/analytics_dashboards/components/visualizations/merge_requests/throughput_table',
};

const Template = (args, { argTypes }) => ({
  components: { MergeRequestsThroughputTable },
  props: Object.keys(argTypes),
  template: `
  <div class="gl-h-48">
    <merge-requests-throughput-table :data="data" :options="options" />
  </div>`,
});

const WithDashboard = (args, { argTypes }) => ({
  components: { MergeRequestsThroughputTable, DashboardLayout },
  props: Object.keys(argTypes),
  template: `
      <dashboard-layout :panels="panelsConfig">
        <merge-requests-throughput-table :data="data" :options="options" />
      </dashboard-layout>`,
});

const defaultArgs = {
  data: {
    list,
    pageInfo: INITIAL_PAGINATION_STATE,
  },
};

export const Default = Template.bind({});
Default.args = defaultArgs;

export const InDashboardPanel = WithDashboard.bind({});
InDashboardPanel.args = {
  ...defaultArgs,
  panelsConfig: [
    {
      id: '1',
      title: 'Panel #1',
      gridAttributes: {
        yPos: 0,
        xPos: 0,
        width: 12,
        height: 3,
      },
    },
  ],
};
