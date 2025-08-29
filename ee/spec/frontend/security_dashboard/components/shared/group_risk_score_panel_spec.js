import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlDashboardPanel } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import GroupRiskScorePanel from 'ee/security_dashboard/components/shared/group_risk_score_panel.vue';
import TotalRiskScore from 'ee/security_dashboard/components/shared/charts/total_risk_score.vue';
import groupTotalRiskScore from 'ee/security_dashboard/graphql/queries/group_total_risk_score.query.graphql';

Vue.use(VueApollo);

describe('GroupRiskScorePanel', () => {
  let wrapper;
  let riskScoreHandler;

  const mockGroupFullPath = 'group/subgroup';
  const mockFilters = { projectId: 'gid://gitlab/Project/123' };
  const defaultRiskScore = 50;
  const defaultMockRiskScoreData = {
    data: {
      group: {
        id: 'gid://gitlab/Group/1',
        securityMetrics: {
          riskScore: {
            score: defaultRiskScore,
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
  });

  describe('Apollo query', () => {
    it('fetches total risk score when component is created', () => {
      expect(riskScoreHandler).toHaveBeenCalledWith({
        fullPath: mockGroupFullPath,
        projectId: mockFilters.projectId,
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
