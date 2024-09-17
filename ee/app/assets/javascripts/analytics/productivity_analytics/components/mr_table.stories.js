import MergeRequestTable from './mr_table.vue';
import { mergeRequests, metricTypes, metricType, metricLabel } from './stories_constants';

// Note: Some custom styling is missing in the storybook bundle
//       from ee/app/assets/stylesheets/page_bundles/productivity_analytics.scss
//       We should review the CSS to see what can be replaced with util classes
// TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/490201

export default {
  component: MergeRequestTable,
  title: 'ee/analytics/productivity_analytics/components/mr_table',
};

const Template = (args, { argTypes }) => ({
  components: { MergeRequestTable },
  props: Object.keys(argTypes),
  template: `
    <merge-request-table v-bind="$props" />`,
});

const defaultArgs = {
  mergeRequests,
  pageInfo: {
    perPage: 2,
    page: 1,
    total: 4,
    totalPages: 2,
    nextPage: null,
    previousPage: null,
  },
  columnOptions: metricTypes,
  metricType,
  metricLabel,
};

export const Default = Template.bind({});
Default.args = defaultArgs;

export const NoPagination = Template.bind({});
NoPagination.args = {
  ...defaultArgs,
  pageInfo: {},
};

export const NoMergeRequests = Template.bind({});
NoMergeRequests.args = {
  ...defaultArgs,
  pageInfo: {},
  mergeRequests: [],
};
