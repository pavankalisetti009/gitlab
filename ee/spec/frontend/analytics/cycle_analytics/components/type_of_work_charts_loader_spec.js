import { shallowMount } from '@vue/test-utils';
import axios from 'axios';
import MockAdapter from 'axios-mock-adapter';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { HTTP_STATUS_NOT_FOUND, HTTP_STATUS_OK } from '~/lib/utils/http_status';
import waitForPromises from 'helpers/wait_for_promises';
import TypeOfWorkChartsLoader from 'ee/analytics/cycle_analytics/components/type_of_work_charts_loader.vue';
import TypeOfWorkCharts from 'ee/analytics/cycle_analytics/components/type_of_work_charts.vue';
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

describe('TypeOfWorkChartsLoader', () => {
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

  const createStore = (state) =>
    new Vuex.Store({
      state: {
        namespace: {
          fullPath: 'fake/group/path',
        },
        createdAfter: new Date('2019-12-11'),
        createdBefore: new Date('2020-01-10'),
      },
      getters: {
        cycleAnalyticsRequestParams: () => cycleAnalyticsRequestParams,
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

  const createWrapper = ({ state = {} } = {}) => {
    wrapper = shallowMount(TypeOfWorkChartsLoader, {
      store: createStore(state),
    });

    return waitForPromises();
  };

  const findLoader = () => wrapper.findComponent(ChartSkeletonLoader);
  const findTypeOfWorkCharts = () => wrapper.findComponent(TypeOfWorkCharts);

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

    it('renders the type of work charts', () => {
      expect(findTypeOfWorkCharts().exists()).toBe(true);
    });

    it('does not render the loading icon', () => {
      expect(findLoader().exists()).toBe(false);
    });

    describe('when update filter is emitted', () => {
      const payload = {
        filter: TASKS_BY_TYPE_FILTERS.SUBJECT,
        value: TASKS_BY_TYPE_SUBJECT_MERGE_REQUEST,
      };

      beforeEach(() => {
        findTypeOfWorkCharts(wrapper).vm.$emit('update-filter', payload);
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
});
