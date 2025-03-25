import GridstackDashboard from 'storybook_helpers/dashboards/gridstack_dashboard.vue';
import GridstackPanel from 'storybook_helpers/dashboards/gridstack_panel.vue';
import DataTable from './data_table.vue';

export default {
  component: DataTable,
  title: 'ee/analytics/analytics_dashboards/components/visualizations/data_table',
};

const Template = (args, { argTypes }) => ({
  components: { DataTable, GridstackDashboard, GridstackPanel },
  props: Object.keys(argTypes),
  template: `<data-table :data="data" :options="options" />`,
});

const WithGridstack = (args, { argTypes }) => ({
  components: { DataTable, GridstackDashboard, GridstackPanel },
  props: Object.keys(argTypes),
  template: `
      <gridstack-dashboard :panels="panelsConfig">
        <data-table :data="data" :options="options" />
      </gridstack-dashboard>`,
});

const data = [
  {
    title: 'MR 0',
    additions: 1,
    deletions: 0,
    commitCount: 1,
    userNotesCount: 1,
  },
  {
    title: 'MR 1',
    additions: 1,
    deletions: 0,
    commitCount: 1,
    userNotesCount: 1,
  },
  {
    title: 'MR 2',
    additions: 4,
    deletions: 3,
    commitCount: 10,
    userNotesCount: 1,
  },
  {
    title: 'MR 3',
    additions: 20,
    deletions: 4,
    commitCount: 40,
    userNotesCount: 1,
  },
];

const defaultArgs = {
  data,
  options: {
    decimalPlaces: 1,
  },
};

export const Default = Template.bind({});
Default.args = defaultArgs;

export const InDashboardPanel = WithGridstack.bind({});
InDashboardPanel.args = {
  ...defaultArgs,
  panelsConfig: [
    {
      id: '1',
      title: 'Awesome data table',
      gridAttributes: {
        yPos: 0,
        xPos: 0,
        width: 9,
        height: 3,
      },
    },
  ],
};
