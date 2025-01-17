import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { shallowMount } from '@vue/test-utils';
import DurationChartLoader from 'ee/analytics/cycle_analytics/components/duration_charts/duration_chart_loader.vue';
import StageChart from 'ee/analytics/cycle_analytics/components/duration_charts/stage_chart.vue';
import OverviewChart from 'ee/analytics/cycle_analytics/components/duration_charts/overview_chart.vue';
import {
  allowedStages as stages,
  durationChartPlottableData,
  durationOverviewChartPlottableData,
} from '../../mock_data';

Vue.use(Vuex);

describe('DurationChartLoader', () => {
  let wrapper;

  const [selectedStage] = stages;
  const fetchDurationData = jest.fn();

  const createWrapper = ({ state = {}, isOverviewStageSelected = true } = {}) => {
    const store = new Vuex.Store({
      state: {
        selectedStage,
      },
      getters: {
        isOverviewStageSelected: () => isOverviewStageSelected,
      },
      mutations: {
        setSelectedStage: (rootState, value) => {
          // eslint-disable-next-line no-param-reassign
          rootState.selectedStage = value;
        },
      },
      modules: {
        durationChart: {
          namespaced: true,
          state: {
            isLoading: false,
            errorMessage: '',
            ...state,
          },
          getters: {
            durationChartPlottableData: () => durationChartPlottableData,
            durationOverviewChartPlottableData: () => durationOverviewChartPlottableData,
          },
          actions: {
            fetchDurationData,
          },
        },
      },
    });

    wrapper = shallowMount(DurationChartLoader, { store });
  };

  const findOverviewChart = () => wrapper.findComponent(OverviewChart);
  const findStageChart = () => wrapper.findComponent(StageChart);

  describe('fetches chart data', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('when the component is created', () => {
      expect(fetchDurationData).toHaveBeenCalledTimes(1);
    });

    it('when the selectedStage changes', async () => {
      const [, newStage] = stages;
      wrapper.vm.$store.commit('setSelectedStage', newStage);

      await nextTick();

      expect(fetchDurationData).toHaveBeenCalledTimes(2);
    });
  });

  describe('overview chart', () => {
    it('shows the chart with the plottable data', () => {
      createWrapper();

      expect(findOverviewChart().props()).toMatchObject({
        isLoading: false,
        errorMessage: '',
        plottableData: durationOverviewChartPlottableData,
      });
    });

    it('does not show the stage chart', () => {
      createWrapper();

      expect(findStageChart().exists()).toBe(false);
    });

    it('shows the loading state', () => {
      createWrapper({ state: { isLoading: true } });

      expect(findOverviewChart().props('isLoading')).toBe(true);
    });

    it('shows the error message', () => {
      const errorMessage = 'beep beep';
      createWrapper({ state: { errorMessage } });

      expect(findOverviewChart().props('errorMessage')).toBe(errorMessage);
    });
  });

  describe('stage chart', () => {
    it('shows the chart with the plottable data', () => {
      createWrapper({ isOverviewStageSelected: false });

      expect(findStageChart().props()).toMatchObject({
        stageTitle: selectedStage.title,
        isLoading: false,
        errorMessage: '',
        plottableData: durationChartPlottableData,
      });
    });

    it('does not show the overview chart', () => {
      createWrapper({ isOverviewStageSelected: false });

      expect(findOverviewChart().exists()).toBe(false);
    });

    it('shows the loading state', () => {
      createWrapper({ isOverviewStageSelected: false, state: { isLoading: true } });

      expect(findStageChart().props('isLoading')).toBe(true);
    });

    it('shows the error message', () => {
      const errorMessage = 'beep beep';
      createWrapper({ isOverviewStageSelected: false, state: { errorMessage } });

      expect(findStageChart().props('errorMessage')).toBe(errorMessage);
    });
  });
});
