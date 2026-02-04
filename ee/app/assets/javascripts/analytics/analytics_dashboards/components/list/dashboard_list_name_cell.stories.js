import DashboardListNameCell from './dashboard_list_name_cell.vue';

export default {
  component: DashboardListNameCell,
  title: 'ee/analytics/analytics_dashboards/components/list/dashboard_list_name_cell',
};

const Template = (args, { argTypes }) => ({
  components: { DashboardListNameCell },
  props: Object.keys(argTypes),
  template: `<dashboard-list-name-cell v-bind="$props" />`,
});

const defaultArgs = {
  name: 'Built in dashboard',
  description: 'Built in dashboard',
  isStarred: true,
  dashboardUrl: '/fake/link/to/share',
};

export const Default = Template.bind({});
Default.args = defaultArgs;

export const NotStarred = Template.bind({});
NotStarred.args = {
  ...defaultArgs,
  isStarred: false,
};
