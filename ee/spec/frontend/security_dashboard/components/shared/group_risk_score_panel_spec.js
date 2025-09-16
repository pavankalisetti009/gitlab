import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlDashboardPanel } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
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
        path: 'project-a',
      },
    },
    {
      rating: 'HIGH',
      score: 70.1,
      project: {
        id: 2,
        name: 'Project B',
        path: 'project-b',
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
            },
          },
        },
      },
    },
  };

  const createComponent = ({ props = {}, mockRiskScoreHandler = null } = {}) => {
    riskScoreHandler =
      mockRiskScoreHandler || jest.fn().mockResolvedValue(defaultMockRiskScoreData);

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

  beforeEach(() => {
    createComponent();
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

    it('passes correct props to the risk score tooltip', async () => {
      expect(findRiskScoreTooltip().props()).toMatchObject({
        vulnerabilitiesAverageScoreFactor: 0,
        isLoading: true,
      });

      await waitForPromises();

      expect(findRiskScoreTooltip().props()).toMatchObject({
        vulnerabilitiesAverageScoreFactor: defaultVulnerabilitiesAverageScore,
        isLoading: false,
      });
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
  });

  describe('Apollo query', () => {
    it('fetches total risk score when component is created', () => {
      expect(riskScoreHandler).toHaveBeenCalledWith({
        fullPath: mockGroupFullPath,
        projectId: mockFilters.projectId,
        includeByDefault: true,
        includeByProject: false,
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
        }),
      );
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
