import DashboardLayout from 'storybook_helpers/dashboards/dashboard_layout.vue';
import BarChart from './bar_chart.vue';

export default {
  component: BarChart,
  title: 'ee/analytics/analytics_dashboards/components/visualizations/bar_chart',
};

const Template = (args, { argTypes }) => ({
  components: { BarChart, DashboardLayout },
  props: Object.keys(argTypes),
  template: `
  <div class="gl-h-48">
    <bar-chart :data="data" :options="options" />
  </div>`,
});

const WithDashboard = (args, { argTypes }) => ({
  components: { BarChart, DashboardLayout },
  props: Object.keys(argTypes),
  template: `
      <dashboard-layout :panels="panelsConfig">
        <bar-chart :data="data" :options="options" />
      </dashboard-layout>`,
});

const defaultArgs = {
  data: {
    PromptsAcceptedByLanguage: [
      [875, 'JavaScript'],
      [720, 'Python'],
      [640, 'Java'],
      [580, 'TypeScript'],
      [490, 'C++'],
      [385, 'Go'],
      [320, 'Rust'],
      [275, 'Swift'],
      [195, 'Kotlin'],
    ],
  },
  options: {
    xAxis: { type: 'value', name: 'Accepted prompts' },
    yAxis: { type: 'category', name: 'Language' },
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
