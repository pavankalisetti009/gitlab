import { withVuexStore } from 'storybook_addons/vuex_store';
import OverviewChart from './overview_chart.vue';
import { overviewChartData } from './stories_constants';

export default {
  component: OverviewChart,
  title: 'ee/analytics/cycle_analytics/components/overview_chart',
  decorators: [withVuexStore],
};

const createStoryWithState = ({ durationChart: { getters, state } = {} }) => {
  return (args, { argTypes, createVuexStore }) => ({
    components: { OverviewChart },
    props: Object.keys(argTypes),
    template: '<overview-chart v-bind="$props" />',
    store: createVuexStore({
      modules: {
        durationChart: {
          namespaced: true,
          getters: {
            durationOverviewChartPlottableData: () => overviewChartData,
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
