import { shallowMount } from '@vue/test-utils';
import axios from 'axios';
import MockAdapter from 'axios-mock-adapter';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { HTTP_STATUS_NOT_FOUND, HTTP_STATUS_OK } from '~/lib/utils/http_status';
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
import { createAlert } from '~/alert';
import ChartSkeletonLoader from '~/vue_shared/components/resizable_chart/skeleton_loader.vue';
import { rawTasksByTypeData, groupLabelNames, endpoints } from '../mock_data';

Vue.use(Vuex);
jest.mock('~/alert');

describe('TypeOfWorkCharts', () => {
  let wrapper;
  let mock;

  const fetchTopRankedGroupLabels = jest.fn();
  const setTasksByTypeFilters = jest.fn();

  const cycleAnalyticsRequestParams = {
    project_ids: null,
    created_after: '2019-12-11',
    created_before: '2020-01-10',
    author_username: null,
    milestone_title: null,
    assignee_username: null,
  };

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
        cycleAnalyticsRequestParams: () => cycleAnalyticsRequestParams,
        ...rootGetters,
      },
      modules: {
        typeOfWork: {
          ...typeOfWorkModule,
          state: {
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

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

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
      mock.onGet(endpoints.tasksByTypeData).replyOnce(HTTP_STATUS_OK, rawTasksByTypeData);
      return createWrapper();
    });

    it('calls the `fetchTopRankedGroupLabels` action', () => {
      expect(fetchTopRankedGroupLabels).toHaveBeenCalled();
    });

    it('fetches tasks by type', () => {
      expect(mock.history.get.length).toBe(1);
      expect(mock.history.get[0]).toEqual(
        expect.objectContaining({
          url: '/fake/group/path/-/analytics/type_of_work/tasks_by_type',
          params: {
            ...cycleAnalyticsRequestParams,
            subject: TASKS_BY_TYPE_SUBJECT_ISSUE,
            label_names: groupLabelNames,
          },
        }),
      );
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

      it('refetches the tasks by type', () => {
        expect(mock.history.get.length).toBe(2);
        expect(mock.history.get[1]).toEqual(
          expect.objectContaining({
            url: '/fake/group/path/-/analytics/type_of_work/tasks_by_type',
            params: {
              ...cycleAnalyticsRequestParams,
              subject: TASKS_BY_TYPE_SUBJECT_ISSUE,
              label_names: groupLabelNames,
            },
          }),
        );
      });
    });
  });

  describe('when tasks by type returns 200 with a data error', () => {
    beforeEach(() => {
      mock.onGet(endpoints.tasksByTypeData).replyOnce(HTTP_STATUS_OK, { error: 'Too much data' });
      return createWrapper();
    });

    it('does not show an alert', () => {
      expect(createAlert).not.toHaveBeenCalled();
    });
  });

  describe('when tasks by type throws an error', () => {
    beforeEach(() => {
      mock.onGet(endpoints.tasksByTypeData).replyOnce(HTTP_STATUS_NOT_FOUND, { error: 'error' });
      return createWrapper();
    });

    it('shows an error alert', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'There was an error fetching data for the tasks by type chart',
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
