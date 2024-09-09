import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import waitForPromises from 'helpers/wait_for_promises';
import TasksByTypeChart from 'ee/analytics/cycle_analytics/components/tasks_by_type/chart.vue';
import TasksByTypeFilters from 'ee/analytics/cycle_analytics/components/tasks_by_type/filters.vue';
import TypeOfWorkCharts from 'ee/analytics/cycle_analytics/components/type_of_work_charts.vue';
import NoDataAvailableState from 'ee/analytics/cycle_analytics/components/no_data_available_state.vue';
import typeOfWorkModule from 'ee/analytics/cycle_analytics/store/modules/type_of_work';
import {
  TASKS_BY_TYPE_SUBJECT_MERGE_REQUEST,
  TASKS_BY_TYPE_FILTERS,
  TASKS_BY_TYPE_SUBJECT_ISSUE,
} from 'ee/analytics/cycle_analytics/constants';
import ChartSkeletonLoader from '~/vue_shared/components/resizable_chart/skeleton_loader.vue';
import { rawTasksByTypeData, groupLabelNames } from '../mock_data';

Vue.use(Vuex);
jest.mock('~/alert');

describe('TypeOfWorkCharts', () => {
  let wrapper;

  const fetchTopRankedGroupLabels = jest.fn();
  const setTasksByTypeFilters = jest.fn();

  const createStore = (state, rootGetters) =>
    new Vuex.Store({
      state: {
        namespace: {
          fullPath: 'fake/group/path',
          name: 'Gitlab Org',
          type: 'Group',
        },
        createdAfter: new Date('2019-12-11'),
        createdBefore: new Date('2020-01-10'),
      },
      getters: {
        namespacePath: () => 'fake/group/path',
        selectedProjectIds: () => [],
        cycleAnalyticsRequestParams: () => ({
          project_ids: null,
          created_after: '2019-12-11',
          created_before: '2020-01-10',
          author_username: null,
          milestone_title: null,
          assignee_username: null,
        }),
        ...rootGetters,
      },
      modules: {
        typeOfWork: {
          ...typeOfWorkModule,
          state: {
            data: rawTasksByTypeData,
            subject: TASKS_BY_TYPE_SUBJECT_ISSUE,
            ...typeOfWorkModule.state,
            ...state,
          },
          getters: {
            ...typeOfWorkModule.getters,
            selectedLabelNames: () => groupLabelNames,
          },
          actions: {
            ...typeOfWorkModule.actions,
            fetchTopRankedGroupLabels,
            setTasksByTypeFilters,
          },
        },
      },
    });

  const createWrapper = ({ state = {}, rootGetters = {}, stubs = {} } = {}) => {
    wrapper = shallowMount(TypeOfWorkCharts, {
      store: createStore(state, rootGetters),
      stubs: {
        TasksByTypeChart: true,
        TasksByTypeFilters: true,
        ...stubs,
      },
    });

    return waitForPromises();
  };

  const findSubjectFilters = () => wrapper.findComponent(TasksByTypeFilters);
  const findTasksByTypeChart = () => wrapper.findComponent(TasksByTypeChart);
  const findLoader = () => wrapper.findComponent(ChartSkeletonLoader);
  const findNoDataAvailableState = () => wrapper.findComponent(NoDataAvailableState);

  describe('when loading', () => {
    beforeEach(() => {
      createWrapper({ state: { isLoading: true } });
    });

    it('renders skeleton loader', () => {
      expect(findLoader().exists()).toBe(true);
    });
  });

  describe('with data', () => {
    beforeEach(() => {
      return createWrapper();
    });

    it('calls the `fetchTopRankedGroupLabels` action', () => {
      expect(fetchTopRankedGroupLabels).toHaveBeenCalled();
    });

    it('renders the task by type chart', () => {
      expect(findTasksByTypeChart().exists()).toBe(true);
    });

    it('renders a description of the current filters', () => {
      expect(wrapper.text()).toContain(
        "Shows issues and 3 labels for group 'Gitlab Org' from Dec 11, 2019 to Jan 10, 2020",
      );
    });

    it('does not render the loading icon', () => {
      expect(findLoader(wrapper).exists()).toBe(false);
    });

    describe('when a filter is selected', () => {
      const payload = {
        filter: TASKS_BY_TYPE_FILTERS.SUBJECT,
        value: TASKS_BY_TYPE_SUBJECT_MERGE_REQUEST,
      };

      beforeEach(() => {
        findSubjectFilters(wrapper).vm.$emit('update-filter', payload);
      });

      it('calls the setTasksByTypeFilters method', () => {
        expect(setTasksByTypeFilters).toHaveBeenCalledWith(expect.any(Object), payload);
      });
    });
  });

  describe('with selected projects', () => {
    const createWithProjects = (projectIds) =>
      createWrapper({
        rootGetters: {
          selectedProjectIds: () => projectIds,
        },
      });

    it('renders multiple selected project counts', async () => {
      await createWithProjects([1, 2]);
      expect(wrapper.text()).toContain(
        "Shows issues and 3 labels for group 'Gitlab Org' and 2 projects from Dec 11, 2019 to Jan 10, 2020",
      );
    });

    it('renders one selected project count', async () => {
      await createWithProjects([1]);
      expect(wrapper.text()).toContain(
        "Shows issues and 3 labels for group 'Gitlab Org' and 1 project from Dec 11, 2019 to Jan 10, 2020",
      );
    });
  });

  describe('with no data', () => {
    beforeEach(() => {
      return createWrapper({ state: { data: [] } });
    });

    it('does not renders the task by type chart', () => {
      expect(findTasksByTypeChart(wrapper).exists()).toBe(false);
    });

    it('renders the no data available message', () => {
      expect(findNoDataAvailableState(wrapper).exists()).toBe(true);
    });
  });
});
