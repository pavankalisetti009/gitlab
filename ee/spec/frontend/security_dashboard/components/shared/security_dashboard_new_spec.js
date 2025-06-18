import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import DashboardLayout from '~/vue_shared/components/customizable_dashboard/dashboard_layout.vue';
import PanelsBase from '~/vue_shared/components/customizable_dashboard/panels_base.vue';
import VulnerabilitiesOverTimeChart from 'ee/security_dashboard/components/shared/charts/open_vulnerabilities_over_time.vue';
import GroupSecurityDashboardV2 from 'ee/security_dashboard/components/shared/security_dashboard_new.vue';
import getVulnerabilitiesOverTime from 'ee/security_dashboard/graphql/queries/get_vulnerabilities_over_time.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('Security Dashboard (new version) - Component', () => {
  let wrapper;

  const mockGroupFullPath = 'group/subgroup';

  const mockVulnerabilitiesOverTimeData = {
    data: {
      group: {
        id: 'gid://gitlab/Group/1',
        securityMetrics: {
          vulnerabilitiesOverTime: {
            nodes: [
              {
                date: '2025-06-01',
                bySeverity: [
                  { severity: 'critical', count: 5 },
                  { severity: 'high', count: 10 },
                  { severity: 'medium', count: 15 },
                  { severity: 'low', count: 8 },
                ],
              },
              {
                date: '2025-06-02',
                bySeverity: [
                  { severity: 'critical', count: 6 },
                  { severity: 'high', count: 9 },
                  { severity: 'medium', count: 14 },
                  { severity: 'low', count: 7 },
                ],
              },
            ],
          },
        },
      },
    },
  };

  const createComponent = ({
    props = {},
    vulnerabilitiesOverTimeHandler = jest.fn().mockResolvedValue(mockVulnerabilitiesOverTimeData),
  } = {}) => {
    const apolloProvider = createMockApollo([
      [getVulnerabilitiesOverTime, vulnerabilitiesOverTimeHandler],
    ]);

    wrapper = mountExtended(GroupSecurityDashboardV2, {
      apolloProvider,
      propsData: {
        ...props,
      },
      provide: {
        groupFullPath: mockGroupFullPath,
      },
    });
  };

  const findDashboardLayout = () => wrapper.findComponent(DashboardLayout);
  const getDashboardConfig = () => findDashboardLayout().props('config');
  const getFirstPanel = () => getDashboardConfig().panels[0];

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('renders the dashboard layout component', () => {
      expect(findDashboardLayout().exists()).toBe(true);
    });

    it('passes the correct dashboard configuration to the layout', () => {
      const dashboardConfig = getDashboardConfig();

      expect(dashboardConfig.title).toBe('Security dashboard');
      expect(dashboardConfig.description).toBe(
        'This dashboard provides an overview of your security vulnerabilities.',
      );
    });

    it('renders the panels with correct configuration', () => {
      const firstPanel = getFirstPanel();

      expect(firstPanel.title).toBe('Vulnerabilities over time');
      expect(firstPanel.component).toBe(VulnerabilitiesOverTimeChart);
      expect(firstPanel.gridAttributes).toEqual({
        width: 6,
        height: 4,
        yPos: 0,
        xPos: 0,
      });
    });
  });

  describe('chart data retrieval', () => {
    it('fetches vulnerabilities over time data when component is created', () => {
      const vulnerabilitiesOverTimeHandler = jest
        .fn()
        .mockResolvedValue(mockVulnerabilitiesOverTimeData);
      createComponent({ vulnerabilitiesOverTimeHandler });

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith({
        fullPath: mockGroupFullPath,
      });
    });

    it('correctly formats chart data from the API response', async () => {
      createComponent();
      await waitForPromises();
      await nextTick();

      const expectedChartData = [
        {
          name: 'Critical',
          data: [
            ['2025-06-01', 5],
            ['2025-06-02', 6],
          ],
        },
        {
          name: 'High',
          data: [
            ['2025-06-01', 10],
            ['2025-06-02', 9],
          ],
        },
        {
          name: 'Medium',
          data: [
            ['2025-06-01', 15],
            ['2025-06-02', 14],
          ],
        },
        {
          name: 'Low',
          data: [
            ['2025-06-01', 8],
            ['2025-06-02', 7],
          ],
        },
        { name: 'Info', data: [] },
        { name: 'Unknown', data: [] },
      ];

      expect(getFirstPanel().componentProps.chartSeries).toEqual(expectedChartData);
    });

    it('returns empty chart data when no vulnerabilities data is available', async () => {
      const emptyResponse = {
        data: {
          group: {
            id: 'gid://gitlab/Group/1',
            securityMetrics: {
              vulnerabilitiesOverTime: {
                nodes: [],
              },
            },
          },
        },
      };

      const vulnerabilitiesOverTimeHandler = jest.fn().mockResolvedValue(emptyResponse);
      createComponent({ vulnerabilitiesOverTimeHandler });
      await waitForPromises();

      expect(getFirstPanel().componentProps.chartSeries).toEqual([]);
    });
  });

  describe('error handling', () => {
    describe.each`
      errorType                   | vulnerabilitiesOverTimeHandler
      ${'GraphQL query failures'} | ${jest.fn().mockRejectedValue(new Error('GraphQL query failed'))}
      ${'server error responses'} | ${jest.fn().mockResolvedValue({ errors: [{ message: 'Internal server error' }] })}
    `('$errorType', ({ vulnerabilitiesOverTimeHandler }) => {
      it('does not render the chart component', async () => {
        createComponent({ vulnerabilitiesOverTimeHandler });
        await waitForPromises();

        expect(wrapper.findComponent('VulnerabilitiesOverTimeChart').exists()).toBe(false);
      });

      it('sets the panel alert state', async () => {
        createComponent({ vulnerabilitiesOverTimeHandler });
        await waitForPromises();

        expect(getFirstPanel().showAlertState).toBe(true);
      });

      it('renders the correct error message', async () => {
        createComponent({ vulnerabilitiesOverTimeHandler });
        await waitForPromises();

        const panelsBase = wrapper.findComponent(PanelsBase);

        expect(panelsBase.text()).toContain('Something went wrong. Please try again.');
      });
    });
  });
});
