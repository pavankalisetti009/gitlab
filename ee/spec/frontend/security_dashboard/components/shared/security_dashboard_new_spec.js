import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { markRaw } from '~/lib/utils/vue3compat/mark_raw';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DashboardLayout from '~/vue_shared/components/customizable_dashboard/dashboard_layout.vue';
import PanelsBase from '~/vue_shared/components/customizable_dashboard/panels_base.vue';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import VulnerabilitiesOverTimeChart from 'ee/security_dashboard/components/shared/charts/open_vulnerabilities_over_time.vue';
import FilteredSearch from 'ee/security_dashboard/components/shared/security_dashboard_filtered_search/filtered_search.vue';
import GroupSecurityDashboardV2 from 'ee/security_dashboard/components/shared/security_dashboard_new.vue';
import getVulnerabilitiesOverTime from 'ee/security_dashboard/graphql/queries/get_vulnerabilities_over_time.query.graphql';
import ProjectToken from 'ee/security_dashboard/components/shared/filtered_search_v2/tokens/project_token.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('Security Dashboard (new version) - Component', () => {
  let wrapper;

  const mockGroupFullPath = 'group/subgroup';

  const defaultMockVulnerabilitiesOverTimeData = {
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
    mountFn = shallowMountExtended,
    mockVulnerabilitiesOverTimeHandler = null,
  } = {}) => {
    const vulnerabilitiesOverTimeHandler =
      mockVulnerabilitiesOverTimeHandler ||
      jest.fn().mockResolvedValue(defaultMockVulnerabilitiesOverTimeData);

    const apolloProvider = createMockApollo([
      [getVulnerabilitiesOverTime, vulnerabilitiesOverTimeHandler],
    ]);

    wrapper = mountFn(GroupSecurityDashboardV2, {
      apolloProvider,
      propsData: {
        ...props,
      },
      provide: {
        groupFullPath: mockGroupFullPath,
      },
    });

    return { vulnerabilitiesOverTimeHandler };
  };

  const findDashboardLayout = () => wrapper.findComponent(DashboardLayout);
  const findFilteredSearch = () => wrapper.findComponent(FilteredSearch);
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
      const { vulnerabilitiesOverTimeHandler } = createComponent();

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

      createComponent({
        mockVulnerabilitiesOverTimeHandler: jest.fn().mockResolvedValue(emptyResponse),
      });
      await waitForPromises();

      expect(getFirstPanel().componentProps.chartSeries).toEqual([]);
    });
  });

  describe('filtered search', () => {
    it('gets passed the correct tokens', () => {
      expect(findFilteredSearch().props('tokens')).toMatchObject(
        expect.arrayContaining([
          expect.objectContaining({
            type: 'projectId',
            title: 'Project',
            multiSelect: true,
            unique: true,
            token: markRaw(ProjectToken),
            operators: OPERATORS_OR,
          }),
        ]),
      );
    });

    it('updates filters when filters-changed event is emitted', async () => {
      const { vulnerabilitiesOverTimeHandler } = createComponent();

      const newFilters = { projectId: 'gid://gitlab/Project/123' };
      findFilteredSearch().vm.$emit('filters-changed', newFilters);
      await waitForPromises();

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenLastCalledWith({
        fullPath: mockGroupFullPath,
        ...newFilters,
      });
    });

    it('clears filters when empty filters object is emitted', async () => {
      const { vulnerabilitiesOverTimeHandler } = createComponent();

      const initialFilters = { projectId: 'gid://gitlab/Project/123' };
      findFilteredSearch().vm.$emit('filters-changed', initialFilters);

      await waitForPromises();

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenLastCalledWith({
        fullPath: mockGroupFullPath,
        ...initialFilters,
      });

      // Clear filters
      findFilteredSearch().vm.$emit('filters-changed', {});
      await waitForPromises();

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenLastCalledWith({
        fullPath: mockGroupFullPath,
      });
    });

    it('includes projectId in GraphQL variables when project filter is set', async () => {
      const { vulnerabilitiesOverTimeHandler } = createComponent();

      const projectId = 'gid://gitlab/Project/123';
      findFilteredSearch().vm.$emit('filters-changed', { projectId });
      await waitForPromises();

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith({
        fullPath: mockGroupFullPath,
        projectId,
      });
    });
  });

  describe('error handling', () => {
    describe.each`
      errorType                   | mockVulnerabilitiesOverTimeHandler
      ${'GraphQL query failures'} | ${jest.fn().mockRejectedValue(new Error('GraphQL query failed'))}
      ${'server error responses'} | ${jest.fn().mockResolvedValue({ errors: [{ message: 'Internal server error' }] })}
    `('$errorType', ({ mockVulnerabilitiesOverTimeHandler }) => {
      it('does not render the chart component', async () => {
        createComponent({
          mockVulnerabilitiesOverTimeHandler,
        });
        await waitForPromises();

        expect(wrapper.findComponent('VulnerabilitiesOverTimeChart').exists()).toBe(false);
      });

      it('sets the panel alert state', async () => {
        createComponent({
          mockVulnerabilitiesOverTimeHandler,
        });
        await waitForPromises();

        expect(getFirstPanel().showAlertState).toBe(true);
      });

      it('renders the correct error message', async () => {
        // we need to mount extended here because the error message is deep within scoped slots
        createComponent({
          mockVulnerabilitiesOverTimeHandler,
          mountFn: mountExtended,
        });
        await waitForPromises();

        const panelsBase = wrapper.findComponent(PanelsBase);

        expect(panelsBase.text()).toContain('Something went wrong. Please try again.');
      });
    });
  });
});
