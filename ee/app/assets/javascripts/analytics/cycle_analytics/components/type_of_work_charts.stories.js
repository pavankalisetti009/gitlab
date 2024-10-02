import { withVuexStore } from 'storybook_addons/vuex_store';
import TypeOfWorkCharts from './type_of_work_charts.vue';
import { tasksByTypeChartData, defaultGroupLabels } from './stories_constants';

export default {
  component: TypeOfWorkCharts,
  title: 'ee/analytics/cycle_analytics/components/type_of_work_charts',
  decorators: [withVuexStore],
};

const createStoryWithState = ({ state = {} }) => {
  return (args, { argTypes, createVuexStore }) => ({
    components: { TypeOfWorkCharts },
    props: Object.keys(argTypes),
    template: '<type-of-work-charts v-bind="$props" />',
    store: createVuexStore({
      state: {
        defaultGroupLabels,
        namespace: { name: 'Some namespace' },
        createdAfter: new Date('2023-01-01'),
        createdBefore: new Date('2023-12-31'),
      },
      getters: {
        selectedProjectIds: () => [],
      },
      modules: {
        typeOfWork: {
          namespaced: true,
          state,
          getters: {
            selectedLabelNames: () => [],
          },
        },
      },
    }),
  });
};

export const Default = createStoryWithState({}).bind({});
Default.args = { chartData: tasksByTypeChartData };

export const NoData = createStoryWithState({}).bind({});
NoData.args = { chartData: { data: [] } };

export const ErrorMessage = createStoryWithState({
  state: { errorMessage: 'Failed to load chart' },
}).bind({});
ErrorMessage.args = { chartData: { data: [] } };
