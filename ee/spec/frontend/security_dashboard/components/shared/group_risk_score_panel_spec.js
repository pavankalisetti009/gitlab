import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { merge } from 'lodash';
import { GlDashboardPanel, GlBadge } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import setWindowLocation from 'helpers/set_window_location_helper';
import * as panelStateUrlSync from 'ee/security_dashboard/utils/panel_state_url_sync';
import GroupRiskScorePanel from 'ee/security_dashboard/components/shared/group_risk_score_panel.vue';
import TotalRiskScore from 'ee/security_dashboard/components/shared/charts/total_risk_score.vue';
import RiskScoreByProject from 'ee/security_dashboard/components/shared/charts/risk_score_by_project.vue';
import RiskScoreGroupBy from 'ee/security_dashboard/components/shared/risk_score_group_by.vue';
import RiskScoreTooltip from 'ee/security_dashboard/components/shared/risk_score_tooltip.vue';
import groupTotalRiskScore from 'ee/security_dashboard/graphql/queries/group_total_risk_score.query.graphql';

Vue.use(VueApollo);

describe('GroupRiskScorePanel', () => {
  let wrapper;
  let riskScoreHandler;

  const mockGroupFullPath = 'group/subgroup';
  const mockFilters = { projectId: 'gid://gitlab/Project/123' };
  const defaultRiskScore = 50;
  const defaultVulnerabilitiesAverageScore = 2.5;
  const defaultByProjectMockData = [
    {
      rating: 'CRITICAL',
      score: 85.5,
      project: {
        id: 1,
        name: 'Project A',
        webUrl: 'project-a',
      },
    },
    {
      rating: 'HIGH',
      score: 70.1,
      project: {
        id: 2,
        name: 'Project B',
        webUrl: 'project-b',
      },
    },
  ];
  const defaultMockRiskScoreData = {
    data: {
      group: {
        id: 'gid://gitlab/Group/1',
        securityMetrics: {
          riskScore: {
            score: defaultRiskScore,
            factors: {
              vulnerabilitiesAverageScore: {
                factor: defaultVulnerabilitiesAverageScore,
              },
            },
            byProject: {
              nodes: defaultByProjectMockData,
              pageInfo: {
                hasNextPage: false,
              },
            },
          },
        },
      },
    },
  };

  const createMockData = ({ overrides = {} } = {}) =>
    merge({}, defaultMockRiskScoreData, overrides);

  const createComponent = ({ props = {}, mockRiskScoreHandler = null } = {}) => {
    riskScoreHandler = mockRiskScoreHandler || jest.fn().mockResolvedValue(createMockData());

    const apolloProvider = createMockApollo([[groupTotalRiskScore, riskScoreHandler]]);

    wrapper = shallowMountExtended(GroupRiskScorePanel, {
      apolloProvider,
      propsData: {
        filters: mockFilters,
        ...props,
      },
      provide: {
        groupFullPath: mockGroupFullPath,
      },
    });
  };

  const findDashboardPanel = () => wrapper.findComponent(GlDashboardPanel);
  const findTotalRiskScore = () => wrapper.findComponent(TotalRiskScore);
  const findRiskScoreByProject = () => wrapper.findComponent(RiskScoreByProject);
  const findRiskScoreGroupBy = () => wrapper.findComponent(RiskScoreGroupBy);
  const findRiskScoreTooltip = () => wrapper.findComponent(RiskScoreTooltip);
  const findMaxProjectsBadge = () => wrapper.findComponent(GlBadge);

  beforeEach(() => {
    createComponent();
  });

  afterEach(() => {
    setWindowLocation('');
  });

  describe('component rendering', () => {
    it('sets the correct title for the dashboard panel', () => {
      expect(findDashboardPanel().props('title')).toBe('Risk score');
    });

    it('passes the fetched score to the TotalRiskScore component', async () => {
      expect(findTotalRiskScore().props('score')).toBe(0);

      await waitForPromises();

      expect(findTotalRiskScore().props('score')).toBe(defaultRiskScore);
    });

    it('passes loading state to the dashboard panel', async () => {
      expect(findDashboardPanel().props('loading')).toBe(true);

      await waitForPromises();

      expect(findDashboardPanel().props('loading')).toBe(false);
    });

    it('passes the projects to the risk score by project component', async () => {
      const riskScoreGroupBy = findRiskScoreGroupBy();

      await riskScoreGroupBy.vm.$emit('input', 'project');
      await waitForPromises();

      expect(findRiskScoreByProject().props('riskScores')).toMatchObject(defaultByProjectMockData);
    });

    it('renders the risk score tooltip', () => {
      expect(findRiskScoreTooltip().exists()).toBe(true);
    });
  });

  describe('group by functionality', () => {
    beforeEach(() => {
      createComponent();
    });

    it('switches to project grouping when project button is clicked', async () => {
      await waitForPromises();
      const riskScoreGroupBy = findRiskScoreGroupBy();

      await riskScoreGroupBy.vm.$emit('input', 'project');
      await nextTick();

      expect(riskScoreGroupBy.props('value')).toBe('project');
    });

    it('switches back to "No grouping" grouping when no grouping button is clicked', async () => {
      await waitForPromises();
      const riskScoreGroupBy = findRiskScoreGroupBy();

      await riskScoreGroupBy.vm.$emit('input', 'project');
      await nextTick();

      await riskScoreGroupBy.vm.$emit('input', 'default');
      await nextTick();

      expect(riskScoreGroupBy.props('value')).toBe('default');
    });

    it('initializes with project grouping if URL parameter is set', () => {
      setWindowLocation('?riskScore.groupBy=project');
      createComponent();

      expect(findRiskScoreGroupBy().props('value')).toBe('project');
    });

    it('calls writeToUrl when grouping is set to project', async () => {
      jest.spyOn(panelStateUrlSync, 'writeToUrl');

      findRiskScoreGroupBy().vm.$emit('input', 'project');
      await nextTick();

      expect(panelStateUrlSync.writeToUrl).toHaveBeenCalledWith({
        panelId: 'riskScore',
        paramName: 'groupBy',
        value: 'project',
        defaultValue: 'default',
      });
    });
  });

  describe('Apollo query', () => {
    it('fetches total risk score when component is created', () => {
      expect(riskScoreHandler).toHaveBeenCalledWith({
        fullPath: mockGroupFullPath,
        projectId: mockFilters.projectId,
        includeByDefault: true,
        includeByProject: false,
        projectCount: 96,
      });
    });

    it('passes supported filters to the GraphQL query', () => {
      createComponent({
        props: {
          filters: { projectId: ['gid://gitlab/Project/99'] },
        },
      });

      expect(riskScoreHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          fullPath: mockGroupFullPath,
          projectId: ['gid://gitlab/Project/99'],
          projectCount: 96,
        }),
      );
    });

    it('does not add unsupported filters to the GraphQL query', () => {
      const unsupportedFilter = ['filterValue'];

      createComponent({
        props: {
          filters: { unsupportedFilter },
        },
      });

      expect(riskScoreHandler).not.toHaveBeenCalledWith(
        expect.objectContaining({
          unsupportedFilter,
        }),
      );
    });

    it('updates query variables when switching to report type grouping', async () => {
      await findRiskScoreGroupBy().vm.$emit('input', 'project');
      await waitForPromises();

      expect(riskScoreHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          includeByDefault: false,
          includeByProject: true,
          projectCount: 96,
        }),
      );
    });
  });

  describe('max projects badge', () => {
    const createMockDataWithPageInfo = ({ hasNextPage } = {}) =>
      createMockData({
        overrides: {
          data: {
            group: {
              securityMetrics: {
                riskScore: {
                  byProject: {
                    pageInfo: {
                      hasNextPage,
                    },
                  },
                },
              },
            },
          },
        },
      });

    describe('when groupedBy is "default"', () => {
      it('does not show the badge', async () => {
        createComponent({
          mockRiskScoreHandler: jest
            .fn()
            .mockResolvedValue(createMockDataWithPageInfo({ hasNextPage: false })),
        });

        await waitForPromises();

        expect(findMaxProjectsBadge().exists()).toBe(false);
      });
    });

    describe('when groupedBy is "project"', () => {
      it.each`
        hasNextPage | shouldShow
        ${false}    | ${false}
        ${true}     | ${true}
      `(
        'when hasNextPage is "$hasNextPage", it should show the badge: "$shouldShow"',
        async ({ hasNextPage, shouldShow }) => {
          createComponent({
            mockRiskScoreHandler: jest
              .fn()
              .mockResolvedValue(createMockDataWithPageInfo({ hasNextPage })),
          });

          await findRiskScoreGroupBy().vm.$emit('input', 'project');
          await waitForPromises();

          expect(findMaxProjectsBadge().exists()).toBe(shouldShow);
        },
      );
    });

    describe('badge properties', () => {
      beforeEach(async () => {
        createComponent({
          mockRiskScoreHandler: jest
            .fn()
            .mockResolvedValue(createMockDataWithPageInfo({ hasNextPage: true })),
        });

        await findRiskScoreGroupBy().vm.$emit('input', 'project');
        await waitForPromises();
      });

      it('has the correct variant', () => {
        expect(findMaxProjectsBadge().props('variant')).toBe('neutral');
      });

      it('has the correct text', () => {
        expect(findMaxProjectsBadge().text()).toBe('Max project limit reached');
      });

      it('has the correct tooltip with dynamic threshold', () => {
        const expectedTooltip =
          'Only 96 projects with the highest risk scores are shown. Use the filter at the top of the dashboard to narrow down your results.';
        expect(findMaxProjectsBadge().attributes('title')).toBe(expectedTooltip);
      });
    });
  });

  describe('error handling', () => {
    describe.each`
      errorType                   | mockRiskScoreHandler
      ${'GraphQL query failures'} | ${jest.fn().mockRejectedValue(new Error('GraphQL query failed'))}
      ${'server error responses'} | ${jest.fn().mockResolvedValue({ errors: [{ message: 'Internal server error' }] })}
    `('$errorType', ({ mockRiskScoreHandler }) => {
      beforeEach(async () => {
        createComponent({
          mockRiskScoreHandler,
        });

        await waitForPromises();
      });

      it('sets the dashboard panel to alert state', () => {
        expect(findDashboardPanel().props()).toMatchObject({
          borderColorClass: 'gl-border-t-red-500',
          titleIcon: 'error',
          titleIconClass: 'gl-text-red-500',
        });
      });

      it('shows the correct error message', () => {
        expect(wrapper.find('p').text()).toBe('Something went wrong. Please try again.');
      });
    });
  });
});
