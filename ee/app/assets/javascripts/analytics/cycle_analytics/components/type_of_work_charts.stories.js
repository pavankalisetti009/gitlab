import { withVuexStore } from 'storybook_addons/vuex_store';
import TypeOfWorkCharts from './type_of_work_charts.vue';
import { defaultGroupLabels } from './stories_constants';

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
        namespace: { name: 'Some namespace' },
        createdAfter: new Date('2023-01-01'),
        createdBefore: new Date('2023-12-31'),
      },
      getters: {
        selectedProjectIds: () => [],
        cycleAnalyticsRequestParams: () => ({
          project_ids: null,
          created_after: '2024-01-01',
          created_before: '2024-03-01',
          author_username: null,
          milestone_title: null,
          assignee_username: null,
        }),
      },
      modules: {
        typeOfWork: {
          namespaced: true,
          getters: {
            selectedLabelNames: () => [],
            ...getters,
          },
          state: {
            isLoading: false,
            errorMessage: null,
            topRankedLabels: [],
            ...state,
          },
          actions: {
            fetchTopRankedGroupLabels: () => {},
            setTasksByTypeFilters: () => {},
          },
        },
      },
    }),
  });
};

const defaultState = {};
export const Default = createStoryWithState(defaultState).bind({});

const noDataState = { typeOfWork: { state: { data: [] } } };
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
