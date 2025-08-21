import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import VulnerabilitiesOverTimeChart from 'ee/security_dashboard/components/shared/charts/open_vulnerabilities_over_time.vue';
import GroupVulnerabilitiesOverTimePanel from 'ee/security_dashboard/components/shared/group_vulnerabilities_over_time_panel.vue';
import OverTimeGroupBy from 'ee/security_dashboard/components/shared/over_time_group_by.vue';
import OverTimeSeverityFilter from 'ee/security_dashboard/components/shared/over_time_severity_filter.vue';
import vulnerabilitiesOverTime from 'ee/security_dashboard/graphql/queries/group_vulnerabilities_over_time.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useFakeDate } from 'helpers/fake_date';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('GroupVulnerabilitiesOverTimePanel', () => {
  const todayInIsoFormat = '2022-07-06';
  const ninetyDaysAgoInIsoFormat = '2022-04-07';
  useFakeDate(todayInIsoFormat);

  let wrapper;

  const mockGroupFullPath = 'group/subgroup';
  const mockFilters = { projectId: 'gid://gitlab/Project/123' };

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
                  { severity: 'CRITICAL', count: 5 },
                  { severity: 'HIGH', count: 10 },
                  { severity: 'MEDIUM', count: 15 },
                  { severity: 'LOW', count: 8 },
                ],
                byReportType: [
                  { reportType: 'SAST', count: 8 },
                  { reportType: 'DEPENDENCY_SCANNING', count: 12 },
                  { reportType: 'CONTAINER_SCANNING', count: 10 },
                ],
              },
              {
                date: '2025-06-02',
                bySeverity: [
                  { severity: 'CRITICAL', count: 6 },
                  { severity: 'HIGH', count: 9 },
                  { severity: 'MEDIUM', count: 14 },
                  { severity: 'LOW', count: 7 },
                ],
                byReportType: [
                  { reportType: 'DAST', count: 5 },
                  { reportType: 'API_FUZZING', count: 3 },
                  { reportType: 'SAST', count: 6 },
                ],
              },
            ],
          },
        },
      },
    },
  };

  const createComponent = ({ props = {}, mockVulnerabilitiesOverTimeHandler = null } = {}) => {
    const vulnerabilitiesOverTimeHandler =
      mockVulnerabilitiesOverTimeHandler ||
      jest.fn().mockResolvedValue(defaultMockVulnerabilitiesOverTimeData);

    const apolloProvider = createMockApollo([
      [vulnerabilitiesOverTime, vulnerabilitiesOverTimeHandler],
    ]);

    wrapper = shallowMountExtended(GroupVulnerabilitiesOverTimePanel, {
      apolloProvider,
      propsData: {
        filters: mockFilters,
        ...props,
      },
      provide: {
        groupFullPath: mockGroupFullPath,
        securityVulnerabilitiesPath: '/group/security/vulnerabilities',
      },
    });

    return { vulnerabilitiesOverTimeHandler };
  };

  const findExtendedDashboardPanel = () => wrapper.findComponent(ExtendedDashboardPanel);
  const findVulnerabilitiesOverTimeChart = () =>
    wrapper.findComponent(VulnerabilitiesOverTimeChart);
  const findOverTimeGroupBy = () => wrapper.findComponent(OverTimeGroupBy);
  const findEmptyState = () => wrapper.findByTestId('vulnerabilities-over-time-empty-state');
  const findSeverityFilter = () => wrapper.findComponent(OverTimeSeverityFilter);

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('passes the correct title to the panels base', () => {
      expect(findExtendedDashboardPanel().props('title')).toBe('Vulnerabilities over time');
    });

    it('renders the vulnerabilities over time chart when data is available', async () => {
      await waitForPromises();
      expect(findVulnerabilitiesOverTimeChart().exists()).toBe(true);
    });

    it('passes severity value to OverTimeGroupBy by default', () => {
      expect(findOverTimeGroupBy().props('value')).toBe('severity');
    });
  });

  describe('filters prop', () => {
    it('passes filters to VulnerabilitiesOverTimeChart component', async () => {
      const customFilters = {
        projectId: 'gid://gitlab/Project/456',
        reportType: ['SAST', 'DAST'],
        severity: ['HIGH', 'CRITICAL'],
      };

      const defaultPanelLevelFilters = { severity: [] };

      createComponent({
        props: {
          filters: customFilters,
        },
      });

      await waitForPromises();

      expect(findVulnerabilitiesOverTimeChart().props('filters')).toEqual({
        ...customFilters,
        ...defaultPanelLevelFilters,
      });
    });

    it('passes filters to VulnerabilitiesOverTimeChart when switching group by', async () => {
      const customFilters = {
        projectId: 'gid://gitlab/Project/789',
        reportType: ['CONTAINER_SCANNING'],
      };
      const defaultPanelLevelFilters = { severity: [] };

      createComponent({
        props: {
          filters: customFilters,
        },
      });

      await waitForPromises();

      // Switch to report type grouping
      await findOverTimeGroupBy().vm.$emit('input', 'reportType');
      await waitForPromises();

      expect(findVulnerabilitiesOverTimeChart().props('filters')).toEqual({
        ...customFilters,
        ...defaultPanelLevelFilters,
      });
    });

    it('combines props filters with panel level filters', async () => {
      const customFilters = {
        projectId: 'gid://gitlab/Project/456',
        reportType: ['SAST', 'DAST'],
      };

      const panelLevelFilters = ['HIGH', 'MEDIUM'];

      createComponent({
        props: {
          filters: customFilters,
        },
      });

      await waitForPromises();

      findSeverityFilter().vm.$emit('input', panelLevelFilters);
      await nextTick();

      // The combinedFilters should include both props filters and panel level filters
      expect(findVulnerabilitiesOverTimeChart().props('filters')).toEqual({
        projectId: 'gid://gitlab/Project/456',
        reportType: ['SAST', 'DAST'],
        severity: panelLevelFilters,
      });
    });
  });

  describe('group by functionality', () => {
    beforeEach(() => {
      createComponent();
    });

    it('switches to report type grouping when report type button is clicked', async () => {
      await waitForPromises();
      const overTimeGroupBy = findOverTimeGroupBy();

      await overTimeGroupBy.vm.$emit('input', 'reportType');
      await nextTick();

      expect(overTimeGroupBy.props('value')).toBe('reportType');
    });

    it('switches back to severity grouping when severity button is clicked', async () => {
      await waitForPromises();
      const overTimeGroupBy = findOverTimeGroupBy();

      await overTimeGroupBy.vm.$emit('input', 'reportType');
      await nextTick();

      await overTimeGroupBy.vm.$emit('input', 'severity');
      await nextTick();

      expect(overTimeGroupBy.props('value')).toBe('severity');
    });
  });

  describe('Apollo query', () => {
    beforeEach(() => {
      createComponent();
    });

    it('fetches vulnerabilities over time data when component is created', () => {
      const { vulnerabilitiesOverTimeHandler } = createComponent();

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith({
        fullPath: mockGroupFullPath,
        projectId: mockFilters.projectId,
        startDate: ninetyDaysAgoInIsoFormat,
        endDate: todayInIsoFormat,
        includeBySeverity: true,
        includeByReportType: false,
        severity: [],
        reportType: undefined,
      });
    });

    it.each(['projectId', 'reportType'])(
      'passes filters to the GraphQL query',
      (availableFilterType) => {
        const { vulnerabilitiesOverTimeHandler } = createComponent({
          props: {
            filters: { [availableFilterType]: ['filterValue'] },
          },
        });

        expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            [availableFilterType]: ['filterValue'],
            projectId: availableFilterType === 'projectId' ? ['filterValue'] : undefined,
            reportType: availableFilterType === 'reportType' ? ['filterValue'] : undefined,
          }),
        );
      },
    );

    it('does not add unsupported filters that are passed', () => {
      const unsupportedFilter = ['filterValue'];
      const { vulnerabilitiesOverTimeHandler } = createComponent({
        props: {
          filters: { unsupportedFilter },
        },
      });

      expect(vulnerabilitiesOverTimeHandler).not.toHaveBeenCalledWith(
        expect.objectContaining({
          unsupportedFilter,
        }),
      );
    });

    it('updates query variables when switching to report type grouping', async () => {
      const { vulnerabilitiesOverTimeHandler } = createComponent();

      await findOverTimeGroupBy().vm.$emit('input', 'reportType');
      await waitForPromises();

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          includeBySeverity: false,
          includeByReportType: true,
        }),
      );
    });
  });

  describe('severity filter', () => {
    beforeEach(() => {
      createComponent();
    });

    it('passes the correct value prop', () => {
      expect(findSeverityFilter().props('value')).toEqual([]);
    });

    it('updates the GraphQL query variables when severity filter changes', async () => {
      const { vulnerabilitiesOverTimeHandler } = createComponent();
      const appliedFilters = ['CRITICAL', 'HIGH'];

      findSeverityFilter().vm.$emit('input', appliedFilters);
      await waitForPromises();

      expect(findSeverityFilter().props('value')).toBe(appliedFilters);
      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          severity: appliedFilters,
        }),
      );
    });
  });

  describe('chart data formatting', () => {
    beforeEach(() => {
      createComponent();
    });

    it('correctly formats chart data from the API response for severity grouping', async () => {
      await waitForPromises();

      const expectedChartData = [
        {
          name: 'Critical',
          id: 'CRITICAL',
          data: [
            ['2025-06-01', 5],
            ['2025-06-02', 6],
          ],
        },
        {
          name: 'High',
          id: 'HIGH',
          data: [
            ['2025-06-01', 10],
            ['2025-06-02', 9],
          ],
        },
        {
          name: 'Medium',
          id: 'MEDIUM',
          data: [
            ['2025-06-01', 15],
            ['2025-06-02', 14],
          ],
        },
        {
          name: 'Low',
          id: 'LOW',
          data: [
            ['2025-06-01', 8],
            ['2025-06-02', 7],
          ],
        },
      ];

      expect(findVulnerabilitiesOverTimeChart().props('chartSeries')).toEqual(expectedChartData);
    });

    it('passes the correct grouped-by prop for severity grouping', async () => {
      await waitForPromises();

      expect(findVulnerabilitiesOverTimeChart().props('groupedBy')).toBe('severity');
    });

    it('passes the correct grouped-by prop for report type grouping', async () => {
      await findOverTimeGroupBy().vm.$emit('input', 'reportType');
      await waitForPromises();

      expect(findVulnerabilitiesOverTimeChart().props('groupedBy')).toBe('reportType');
    });

    it('correctly formats chart data from the API response for report type grouping', async () => {
      await findOverTimeGroupBy().vm.$emit('input', 'reportType');
      await waitForPromises();

      const expectedChartData = [
        {
          name: 'SAST',
          id: 'SAST',
          data: [
            ['2025-06-01', 8],
            ['2025-06-02', 6],
          ],
        },
        {
          name: 'Dependency Scanning',
          id: 'DEPENDENCY_SCANNING',
          data: [['2025-06-01', 12]],
        },
        {
          name: 'Container Scanning',
          id: 'CONTAINER_SCANNING',
          data: [['2025-06-01', 10]],
        },
        {
          name: 'DAST',
          id: 'DAST',
          data: [['2025-06-02', 5]],
        },
        {
          name: 'API Fuzzing',
          id: 'API_FUZZING',
          data: [['2025-06-02', 3]],
        },
      ];

      expect(findVulnerabilitiesOverTimeChart().props('chartSeries')).toEqual(expectedChartData);
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

      expect(findVulnerabilitiesOverTimeChart().exists()).toBe(false);
      expect(findEmptyState().text()).toBe('No data available.');
    });
  });

  describe('loading state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('passes loading state to panels base', async () => {
      expect(findExtendedDashboardPanel().props('loading')).toBe(true);

      await waitForPromises();

      expect(findExtendedDashboardPanel().props('loading')).toBe(false);
    });
  });

  describe('error handling', () => {
    describe.each`
      errorType                   | mockVulnerabilitiesOverTimeHandler
      ${'GraphQL query failures'} | ${jest.fn().mockRejectedValue(new Error('GraphQL query failed'))}
      ${'server error responses'} | ${jest.fn().mockResolvedValue({ errors: [{ message: 'Internal server error' }] })}
    `('$errorType', ({ mockVulnerabilitiesOverTimeHandler }) => {
      beforeEach(async () => {
        createComponent({
          mockVulnerabilitiesOverTimeHandler,
        });

        await waitForPromises();
      });

      it('sets the panel alert state', () => {
        expect(findExtendedDashboardPanel().props('showAlertState')).toBe(true);
      });

      it('does not render the chart component', () => {
        expect(findVulnerabilitiesOverTimeChart().exists()).toBe(false);
      });

      it('renders the correct error message', () => {
        expect(findEmptyState().text()).toBe('Something went wrong. Please try again.');
      });
    });
  });
});
