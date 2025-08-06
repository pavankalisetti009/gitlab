import getCustomizableDashboardQuery from 'ee/analytics/analytics_dashboards/graphql/queries/get_customizable_dashboard.query.graphql';
import getAllCustomizableDashboardsQuery from 'ee/analytics/analytics_dashboards/graphql/queries/get_all_customizable_dashboards.query.graphql';
import * as utils from 'ee/analytics/analytics_dashboards/utils';
import {
  DASHBOARD_SCHEMA_VERSION,
  CATEGORY_SINGLE_STATS,
  CATEGORY_CHARTS,
  CATEGORY_TABLES,
} from 'ee/analytics/analytics_dashboards/constants';
import {
  dashboard,
  TEST_CUSTOM_DASHBOARDS_PROJECT,
  getGraphQLDashboard,
  TEST_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
  TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE,
  TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
  createVisualization,
} from 'ee_jest/analytics/analytics_dashboards/mock_data';
import { createMockClient } from 'helpers/mock_apollo_helper';

describe('Analytics dashboard utils', () => {
  describe('updateApolloCache', () => {
    let apolloClient;
    let mockReadQuery;
    let mockWriteQuery;
    const dashboardSlug = 'analytics_overview';
    const { fullPath } = TEST_CUSTOM_DASHBOARDS_PROJECT;
    const isProject = true;

    const setMockCache = (mockDashboardDetails, mockDashboardsList) => {
      mockReadQuery.mockImplementation(({ query }) => {
        if (query === getCustomizableDashboardQuery) {
          return mockDashboardDetails;
        }
        if (query === getAllCustomizableDashboardsQuery) {
          return mockDashboardsList;
        }

        return null;
      });
    };

    beforeEach(() => {
      apolloClient = createMockClient();

      mockReadQuery = jest.fn();
      mockWriteQuery = jest.fn();
      apolloClient.readQuery = mockReadQuery;
      apolloClient.writeQuery = mockWriteQuery;
    });

    describe('dashboard details cache', () => {
      it('updates an existing dashboard', () => {
        const existingDashboard = getGraphQLDashboard({
          slug: 'some_existing_dash',
          title: 'some existing title',
        });
        const existingDetailsCache = {
          ...TEST_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE.data,
        };
        existingDetailsCache.project.customizableDashboards.nodes = [existingDashboard];

        setMockCache(existingDetailsCache, null);

        utils.updateApolloCache({
          apolloClient,
          slug: existingDashboard.slug,
          dashboard: {
            ...existingDashboard,
            title: 'some new title',
          },
          fullPath,
          isProject,
        });

        expect(mockWriteQuery).toHaveBeenCalledWith(
          expect.objectContaining({
            query: getCustomizableDashboardQuery,
            data: expect.objectContaining({
              project: expect.objectContaining({
                customizableDashboards: expect.objectContaining({
                  nodes: expect.arrayContaining([
                    expect.objectContaining({
                      title: 'some new title',
                    }),
                  ]),
                }),
              }),
            }),
          }),
        );
      });

      it('does not update for new dashboards where cache is empty', () => {
        setMockCache(null, TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE.data);

        utils.updateApolloCache({
          apolloClient,
          slug: dashboardSlug,
          dashboard,
          fullPath,
          isProject,
        });

        expect(mockWriteQuery).not.toHaveBeenCalledWith(
          expect.objectContaining({ query: getCustomizableDashboardQuery }),
        );
      });
    });

    describe('dashboards list', () => {
      it('adds a new dashboard to the dashboards list', () => {
        setMockCache(null, TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE.data);

        utils.updateApolloCache({
          apolloClient,
          slug: dashboardSlug,
          dashboard,
          fullPath,
          isProject,
        });

        expect(mockWriteQuery).toHaveBeenCalledWith(
          expect.objectContaining({
            query: getAllCustomizableDashboardsQuery,
            data: expect.objectContaining({
              project: expect.objectContaining({
                customizableDashboards: expect.objectContaining({
                  nodes: expect.arrayContaining([
                    expect.objectContaining({
                      slug: dashboardSlug,
                    }),
                  ]),
                }),
              }),
            }),
          }),
        );
      });

      it('updates an existing dashboard on the dashboards list', () => {
        setMockCache(null, TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE.data);

        const existingDashboards =
          TEST_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE.data.project.customizableDashboards.nodes;

        const updatedDashboard = {
          ...existingDashboards.at(0),
          title: 'some new title',
        };

        utils.updateApolloCache({
          apolloClient,
          slug: dashboardSlug,
          dashboard: updatedDashboard,
          fullPath,
          isProject,
        });

        expect(mockWriteQuery).toHaveBeenCalledWith(
          expect.objectContaining({
            query: getAllCustomizableDashboardsQuery,
            data: expect.objectContaining({
              project: expect.objectContaining({
                customizableDashboards: expect.objectContaining({
                  nodes: expect.arrayContaining([
                    expect.objectContaining({
                      title: 'some new title',
                    }),
                  ]),
                }),
              }),
            }),
          }),
        );
      });

      it('does not update dashboard list cache when it has not yet been populated', () => {
        setMockCache(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE.data, null);

        utils.updateApolloCache({
          apolloClient,
          slug: dashboardSlug,
          dashboard,
          fullPath,
          isProject,
        });

        expect(mockWriteQuery).not.toHaveBeenCalledWith(
          expect.objectContaining({ query: getAllCustomizableDashboardsQuery }),
        );
      });
    });
  });

  describe('getVisualizationCategory', () => {
    it.each`
      category                 | type
      ${CATEGORY_SINGLE_STATS} | ${'SingleStat'}
      ${CATEGORY_TABLES}       | ${'DataTable'}
      ${CATEGORY_CHARTS}       | ${'LineChart'}
      ${CATEGORY_CHARTS}       | ${'FooBar'}
    `('returns $category when the visualization type is $type', ({ category, type }) => {
      expect(utils.getVisualizationCategory({ type })).toBe(category);
    });
  });

  describe('getDashboardConfig', () => {
    it('maps dashboard to expected value', () => {
      const result = utils.getDashboardConfig(dashboard);
      const visualization = createVisualization();

      expect(result).toMatchObject({
        id: 'analytics_overview',
        version: DASHBOARD_SCHEMA_VERSION,
        panels: [
          {
            gridAttributes: {
              height: 3,
              width: 3,
            },
            queryOverrides: {},
            title: 'Test A',
            visualization,
          },
          {
            gridAttributes: {
              height: 4,
              width: 2,
            },
            queryOverrides: {
              limit: 200,
            },
            title: 'Test B',
            visualization,
          },
        ],
        title: 'Analytics Overview',
        status: null,
        errors: null,
      });
    });

    ['userDefined', 'slug'].forEach((omitted) => {
      it(`omits "${omitted}" dashboard property`, () => {
        const result = utils.getDashboardConfig(dashboard);

        expect(result[omitted]).not.toBeDefined();
      });
    });
  });

  describe('availableVisualizationsValidator', () => {
    it('returns true when the object contains all properties', () => {
      const result = utils.availableVisualizationsValidator({
        loading: false,
        hasError: false,
        visualizations: [],
      });
      expect(result).toBe(true);
    });

    it.each([
      { visualizations: [] },
      { hasError: false },
      { loading: true },
      { loading: true, hasError: false },
    ])('returns false when the object does not contain all properties', (testCase) => {
      const result = utils.availableVisualizationsValidator(testCase);
      expect(result).toBe(false);
    });
  });

  describe('#createNewVisualizationPanel', () => {
    it('returns the expected object', () => {
      const visualization = createVisualization();
      expect(utils.createNewVisualizationPanel(visualization)).toMatchObject({
        visualization: {
          ...visualization,
          errors: null,
        },
        title: 'Test visualization',
        gridAttributes: {
          width: 4,
          height: 3,
        },
        options: {},
      });
    });
  });
});
