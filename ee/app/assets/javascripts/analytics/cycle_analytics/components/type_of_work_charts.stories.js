import { withVuexStore } from 'storybook_addons/vuex_store';
import TypeOfWorkCharts from './type_of_work_charts.vue';
import {
  tasksByTypeChartData,
  selectedTasksByTypeFilters,
  defaultGroupLabels,
} from './stories_constants';

export default {
  component: TypeOfWorkCharts,
  title: 'ee/analytics/cycle_analytics/components/type_of_work_charts',
  decorators: [withVuexStore],
};

const createStoryWithState = ({ typeOfWork: { getters, state } = {} }) => {
  return (args, { argTypes, createVuexStore }) => ({
    components: { TypeOfWorkCharts },
    props: Object.keys(argTypes),
    template: '<type-of-work-charts v-bind="$props" />',
    store: createVuexStore({
      state: {
        defaultGroupLabels,
      },
      modules: {
        typeOfWork: {
          namespaced: true,
          getters: {
            selectedTasksByTypeFilters: () => selectedTasksByTypeFilters,
            tasksByTypeChartData: () => tasksByTypeChartData,
            selectedLabelNames: () => [],
            ...getters,
          },
          state: {
            isLoading: false,
            errorMessage: null,
            topRankedLabels: [],
            ...state,
          },
        },
      },
    }),
  });
};

const defaultState = {};
export const Default = createStoryWithState(defaultState).bind({});

const noDataState = {
  typeOfWork: { getters: { tasksByTypeChartData: () => ({ ...tasksByTypeChartData, data: [] }) } },
};

export const NoData = createStoryWithState(noDataState).bind({});

const isLoadingState = {
  typeOfWork: { state: { isLoading: true } },
};
export const IsLoading = createStoryWithState(isLoadingState).bind({});

const errorState = {
  typeOfWork: {
    ...noDataState.typeOfWork,
    state: { errorMessage: 'Failed to load chart' },
  },
};
export const ErrorMessage = createStoryWithState(errorState).bind({});
