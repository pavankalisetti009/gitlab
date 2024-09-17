import MergeRequestTableRow from './mr_table_row.vue';
import { mergeRequests } from './stories_constants';

// Note: Some custom styling is missing in the storybook bundle
//       from ee/app/assets/stylesheets/page_bundles/productivity_analytics.scss
//       We should review the CSS to see what can be replaced with util classes
// TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/490201

export default {
  component: MergeRequestTableRow,
  title: 'ee/analytics/productivity_analytics/components/mr_table_row',
};

const Template = (args, { argTypes }) => ({
  components: { MergeRequestTableRow },
  props: Object.keys(argTypes),
  template: `<merge-request-table-row v-bind="$props" />`,
});

const defaultArgs = {
  mergeRequest: mergeRequests[0],
  metricType: 'days_to_merge',
  metricLabel: 'Days to merge',
};

export const Default = Template.bind({});
Default.args = defaultArgs;
