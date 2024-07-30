import { withVuexStore } from 'storybook_addons/vuex_store';
import DurationOverviewChart from './duration_overview_chart.vue';
import { durationOverviewChartData } from './stories_constants';

export default {
  component: DurationOverviewChart,
  title: 'ee/analytics/cycle_analytics/components/duration_overview_chart',
  decorators: [withVuexStore],
};

const createStoryWithState = ({ durationChart: { getters, state } = {} }) => {
  return (args, { argTypes, createVuexStore }) => ({
    components: { DurationOverviewChart },
    props: Object.keys(argTypes),
    template: '<duration-overview-chart v-bind="$props" />',
    store: createVuexStore({
      modules: {
        durationChart: {
          namespaced: true,
          getters: {
            durationOverviewChartPlottableData: () => durationOverviewChartData,
            ...getters,
          },
          state: {
            isLoading: false,
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
  durationChart: { getters: { durationOverviewChartPlottableData: () => [] } },
};

export const NoData = createStoryWithState(noDataState).bind({});

const errorState = {
  durationChart: {
    ...noDataState.durationChart,
    state: { errorMessage: 'Failed to load chart' },
  },
};

export const ErrorMessage = createStoryWithState(errorState).bind({});
