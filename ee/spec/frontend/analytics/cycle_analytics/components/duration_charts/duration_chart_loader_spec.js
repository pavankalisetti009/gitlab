import Vue from 'vue';
import VueApollo from 'vue-apollo';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { shallowMount } from '@vue/test-utils';
import { GlAlert } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ChartSkeletonLoader from '~/vue_shared/components/resizable_chart/skeleton_loader.vue';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { createdAfter, createdBefore } from 'jest/analytics/cycle_analytics/mock_data';
import DurationChartLoader from 'ee/analytics/cycle_analytics/components/duration_charts/duration_chart_loader.vue';
import StageChart from 'ee/analytics/cycle_analytics/components/duration_charts/stage_chart.vue';
import StageScatterChart from 'ee/analytics/cycle_analytics/components/duration_charts/stage_scatter_chart.vue';
import OverviewChart from 'ee/analytics/cycle_analytics/components/duration_charts/overview_chart.vue';
import getValueStreamStageAverageDurationsQuery from 'ee/analytics/cycle_analytics/graphql/queries/get_value_stream_stage_average_durations.query.graphql';
import getValueStreamStageMetricsQuery from 'ee/analytics/cycle_analytics/graphql/queries/get_value_stream_stage_metrics.query.graphql';
import {
  allowedStages as stages,
  valueStreams,
  averageDurationsStageQueryResponses,
  mockProjectValueStreamStageMetricsResponse,
  mockGroupValueStreamStageMetricsResponse,
  mockValueStreamStageMetricsNoDataResponse,
  mockProjectValueStreamStageMetricsPaginatedResponse,
  mockGroupValueStreamStageMetricsPaginatedResponse,
} from '../../mock_data';

Vue.use(Vuex);
Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('DurationChartLoader', () => {
  let wrapper;
  let store;
  let averageDurationsQueryHandler;
  let valueStreamStageMetricsQueryHandler;

  const [valueStream] = valueStreams;
  const [selectedStage] = stages;
  const namespacePath = 'fake/group/path';
  const namespace = {
    name: 'GitLab Org',
    path: namespacePath,
  };

  const cycleAnalyticsRequestParams = {
    project_ids: null,
    created_after: '2019-12-11',
    created_before: '2020-01-10',
    author_username: null,
    milestone_title: null,
    assignee_username: null,
    'not[label_name]': null,
  };

  const gqlTransformedFilters = {
    projectIds: null,
    authorUsername: null,
    assigneeUsernames: null,
    milestoneTitle: null,
    not: {
      labelNames: null,
    },
  };

  const defaultValueStreamStageMetricsParams = (isProject) => ({
    fullPath: namespacePath,
    isProject,
    valueStreamId: `gid://gitlab/Analytics::CycleAnalytics::ValueStream/${valueStream.id}`,
    stageId: `gid://gitlab/Analytics::CycleAnalytics::Stage/${selectedStage.id}`,
    startDate: createdAfter,
    endDate: createdBefore,
    ...gqlTransformedFilters,
  });

  const createStore = ({ isOverviewStageSelected, isProjectNamespace }) =>
    new Vuex.Store({
      state: {
        selectedStage,
        createdAfter,
        createdBefore,
        namespace: {
          ...namespace,
          type: isProjectNamespace ? 'Project' : 'Group',
        },
      },
      getters: {
        isOverviewStageSelected: () => isOverviewStageSelected,
        activeStages: () => stages,
        cycleAnalyticsRequestParams: () => cycleAnalyticsRequestParams,
        currentValueStreamId: () => valueStream.id,
        isProjectNamespace: () => isProjectNamespace,
      },
      mutations: {
        setSelectedStage: (rootState, value) => {
          // eslint-disable-next-line no-param-reassign
          rootState.selectedStage = value;
        },
      },
    });

  const createWrapper = ({
    isOverviewStageSelected = true,
    isProjectNamespace = false,
    features = {},
    averageDurationsResponseHandler = null,
    valueStreamStageMetricsResponseHandler = null,
  } = {}) => {
    averageDurationsQueryHandler =
      averageDurationsResponseHandler ||
      jest
        .fn()
        .mockResolvedValueOnce(averageDurationsStageQueryResponses[0])
        .mockResolvedValueOnce(averageDurationsStageQueryResponses[1])
        .mockResolvedValueOnce(averageDurationsStageQueryResponses[2]);

    valueStreamStageMetricsQueryHandler =
      valueStreamStageMetricsResponseHandler ||
      jest.fn().mockResolvedValue(mockGroupValueStreamStageMetricsResponse);

    const apolloProvider = createMockApollo([
      [getValueStreamStageAverageDurationsQuery, averageDurationsQueryHandler],
      [getValueStreamStageMetricsQuery, valueStreamStageMetricsQueryHandler],
    ]);

    store = createStore({ isOverviewStageSelected, isProjectNamespace });

    wrapper = shallowMount(DurationChartLoader, {
      store,
      apolloProvider,
      provide: { glFeatures: { vsaStageTimeScatterChart: true, ...features } },
    });
    return waitForPromises();
  };

  const findLoader = () => wrapper.findComponent(ChartSkeletonLoader);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findOverviewChart = () => wrapper.findComponent(OverviewChart);
  const findStageChart = () => wrapper.findComponent(StageChart);
  const findStageScatterChart = () => wrapper.findComponent(StageScatterChart);

  describe('fetches chart data', () => {
    describe('default', () => {
      beforeEach(() => {
        return createWrapper();
      });

      it('fetches overview chart data', () => {
        expect(averageDurationsQueryHandler).toHaveBeenCalledTimes(stages.length);
      });

      it('does not fetch stage scatter chart data', () => {
        expect(valueStreamStageMetricsQueryHandler).not.toHaveBeenCalled();
      });
    });

    describe.each`
      isProjectNamespace | singlePageResponse                            | paginatedResponse
      ${true}            | ${mockProjectValueStreamStageMetricsResponse} | ${mockProjectValueStreamStageMetricsPaginatedResponse}
      ${false}           | ${mockGroupValueStreamStageMetricsResponse}   | ${mockGroupValueStreamStageMetricsPaginatedResponse}
    `(
      'individual stage selected and isProjectNamespace=$isProjectNamespace',
      ({ isProjectNamespace, singlePageResponse, paginatedResponse }) => {
        beforeEach(() => {
          return createWrapper({
            isOverviewStageSelected: false,
            valueStreamStageMetricsResponseHandler: jest.fn().mockResolvedValue(singlePageResponse),
            isProjectNamespace,
          });
        });

        it('fetches stage scatter chart data', () => {
          expect(valueStreamStageMetricsQueryHandler).toHaveBeenCalledTimes(1);
          expect(valueStreamStageMetricsQueryHandler).toHaveBeenCalledWith(
            defaultValueStreamStageMetricsParams(isProjectNamespace),
          );
        });

        it('does not fetch overview chart data', () => {
          expect(averageDurationsQueryHandler).not.toHaveBeenCalled();
        });

        describe('with additional page of data', () => {
          beforeEach(() => {
            return createWrapper({
              isOverviewStageSelected: false,
              isProjectNamespace,
              valueStreamStageMetricsResponseHandler: jest
                .fn()
                .mockResolvedValueOnce(paginatedResponse)
                .mockResolvedValueOnce(singlePageResponse),
            });
          });

          it('fetches stage scatter chart data correct number of times', () => {
            expect(valueStreamStageMetricsQueryHandler).toHaveBeenCalledTimes(2);

            expect(valueStreamStageMetricsQueryHandler).toHaveBeenNthCalledWith(
              1,
              defaultValueStreamStageMetricsParams(isProjectNamespace),
            );
            expect(valueStreamStageMetricsQueryHandler).toHaveBeenNthCalledWith(2, {
              ...defaultValueStreamStageMetricsParams(isProjectNamespace),
              endCursor: 'GL',
            });
          });
        });

        describe('selected stage changes', () => {
          const [, newStage] = stages;

          beforeEach(async () => {
            store.commit('setSelectedStage', newStage);

            await waitForPromises();
          });

          it('fetches scatter chart data for new stage', () => {
            expect(valueStreamStageMetricsQueryHandler).toHaveBeenCalledTimes(2);
            expect(valueStreamStageMetricsQueryHandler).toHaveBeenCalledWith({
              ...defaultValueStreamStageMetricsParams(isProjectNamespace),
              stageId: `gid://gitlab/Analytics::CycleAnalytics::Stage/${newStage.id}`,
            });
          });

          it('does not fetch overview chart data', () => {
            expect(averageDurationsQueryHandler).not.toHaveBeenCalled();
          });
        });
      },
    );
  });

  describe('overview chart', () => {
    describe('when loading', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('shows the loading state', () => {
        expect(findLoader().exists()).toBe(true);
      });
    });

    describe('when error is thrown', () => {
      beforeEach(() => {
        return createWrapper({
          averageDurationsResponseHandler: jest.fn().mockRejectedValue(new Error('oopsies')),
        });
      });

      it('shows the error message', () => {
        expect(findAlert().text()).toBe('oopsies');
      });

      it('logs the error to sentry', () => {
        expect(Sentry.captureException).toHaveBeenCalled();
      });
    });

    describe('with data', () => {
      beforeEach(() => {
        return createWrapper();
      });

      it('shows the chart with the plottable data', () => {
        expect(findOverviewChart().props().plottableData).toMatchSnapshot();
      });

      it('does not show the stage chart', () => {
        expect(findStageChart().exists()).toBe(false);
      });

      it('does not show the stage scatter chart', () => {
        expect(findStageScatterChart().exists()).toBe(false);
      });
    });
  });

  describe('stage scatter chart', () => {
    describe('when loading', () => {
      beforeEach(() => {
        createWrapper({
          isOverviewStageSelected: false,
          valueStreamStageMetricsResponseHandler: jest.fn().mockReturnValue(new Promise(() => {})),
        });
      });

      it('shows the loading state', () => {
        expect(findLoader().exists()).toBe(true);
      });
    });

    describe('when error is thrown', () => {
      const error = new Error('Something went wrong');

      beforeEach(() => {
        return createWrapper({
          isOverviewStageSelected: false,
          valueStreamStageMetricsResponseHandler: jest.fn().mockRejectedValue(error),
        });
      });

      it('passes error message to chart', () => {
        expect(findAlert().text()).toBe('Something went wrong');
      });

      it('does not show loading state', () => {
        expect(findLoader().exists()).toBe(false);
      });

      it('logs the error to sentry', () => {
        expect(Sentry.captureException).toHaveBeenCalled();
      });

      describe('when selected stage is changed', () => {
        const [, newStage] = stages;

        beforeEach(() => {
          store.commit('setSelectedStage', newStage);
        });

        it('clears the error alert', () => {
          expect(findAlert().exists()).toBe(false);
        });
      });
    });

    describe('with data', () => {
      beforeEach(() => {
        return createWrapper({
          isOverviewStageSelected: false,
        });
      });

      it('shows the chart with plottable data', () => {
        expect(findStageScatterChart().props()).toMatchObject({
          stageTitle: selectedStage.title,
          issuableType: 'Issue',
          plottableData: expect.arrayContaining([
            ['2025-04-29T04:47:24Z', '58606000'],
            ['2025-04-29T05:09:00Z', '668182000'],
          ]),
          startDate: new Date('2018-12-15'),
          endDate: new Date('2019-01-14'),
        });
      });

      it('does not show the overview chart', () => {
        expect(findOverviewChart().exists()).toBe(false);
      });

      it('does not show stage line chart', () => {
        expect(findStageChart().exists()).toBe(false);
      });

      describe('multiple pages of data', () => {
        let resolveFirstPage;
        let resolveSecondPage;

        beforeEach(() => {
          return createWrapper({
            isOverviewStageSelected: false,
            valueStreamStageMetricsResponseHandler: jest
              .fn()
              .mockResolvedValueOnce(
                new Promise((resolve) => {
                  resolveFirstPage = resolve;
                }),
              )
              .mockResolvedValueOnce(
                new Promise((resolve) => {
                  resolveSecondPage = resolve;
                }),
              ),
          });
        });

        it('renders the first page of data before lazy loading subsequent pages', async () => {
          expect(findLoader().exists()).toBe(true);
          expect(findStageScatterChart().exists()).toBe(false);

          resolveFirstPage(mockGroupValueStreamStageMetricsPaginatedResponse);
          await waitForPromises();

          expect(findLoader().exists()).toBe(false);
          expect(findStageScatterChart().props().plottableData).toEqual([
            ['2025-04-13T04:33:20Z', '719706000'],
            ['2025-04-16T16:28:27Z', '1019305000'],
          ]);

          resolveSecondPage(mockGroupValueStreamStageMetricsResponse);
          await waitForPromises();

          expect(findStageScatterChart().props().plottableData).toEqual([
            ['2025-04-13T04:33:20Z', '719706000'],
            ['2025-04-16T16:28:27Z', '1019305000'],
            ['2025-04-29T04:47:24Z', '58606000'],
            ['2025-04-29T05:09:00Z', '668182000'],
          ]);
        });
      });
    });

    describe('with no data', () => {
      beforeEach(() => {
        return createWrapper({
          isOverviewStageSelected: false,
          valueStreamStageMetricsResponseHandler: jest
            .fn()
            .mockResolvedValue(mockValueStreamStageMetricsNoDataResponse),
        });
      });

      it('shows an empty chart', () => {
        expect(findStageScatterChart().props()).toMatchObject({
          stageTitle: selectedStage.title,
          plottableData: [],
        });
      });

      it('does not show the overview chart', () => {
        expect(findOverviewChart().exists()).toBe(false);
      });

      it('does not show stage line chart', () => {
        expect(findStageChart().exists()).toBe(false);
      });
    });
  });

  describe('`vsaStageTimeScatterChart` feature flag is disabled', () => {
    describe('fetches chart data', () => {
      beforeEach(() => {
        return createWrapper({
          features: { vsaStageTimeScatterChart: false },
        });
      });

      it('when the component is created', () => {
        expect(averageDurationsQueryHandler).toHaveBeenCalledTimes(stages.length);
        expect(valueStreamStageMetricsQueryHandler).not.toHaveBeenCalled();
      });

      it('when the selectedStage changes', async () => {
        const [, newStage] = stages;
        store.commit('setSelectedStage', newStage);

        await waitForPromises();

        expect(averageDurationsQueryHandler).toHaveBeenCalledTimes(stages.length);
        expect(valueStreamStageMetricsQueryHandler).not.toHaveBeenCalled();
      });
    });

    describe('stage chart', () => {
      describe('when loading', () => {
        beforeEach(() => {
          createWrapper({
            isOverviewStageSelected: false,
            features: { vsaStageTimeScatterChart: false },
          });
        });

        it('shows the loading state', () => {
          expect(findLoader().exists()).toBe(true);
        });
      });

      describe('when error is thrown', () => {
        beforeEach(() => {
          return createWrapper({
            isOverviewStageSelected: false,
            features: { vsaStageTimeScatterChart: false },
            averageDurationsResponseHandler: jest.fn().mockRejectedValue(new Error('oopsies')),
          });
        });

        it('shows the error message', () => {
          expect(findAlert().text()).toBe('oopsies');
        });

        it('logs the error to sentry', () => {
          expect(Sentry.captureException).toHaveBeenCalled();
        });
      });

      describe('with data', () => {
        beforeEach(() => {
          return createWrapper({
            isOverviewStageSelected: false,
            features: { vsaStageTimeScatterChart: false },
          });
        });

        it('shows the chart with the plottable data', () => {
          expect(findStageChart().props().stageTitle).toBe(selectedStage.title);
          expect(findStageChart().props().plottableData).toMatchSnapshot();
        });

        it('does not show the overview chart', () => {
          expect(findOverviewChart().exists()).toBe(false);
        });

        it('does not show the stage scatter chart', () => {
          expect(findStageScatterChart().exists()).toBe(false);
        });
      });
    });
  });
});
