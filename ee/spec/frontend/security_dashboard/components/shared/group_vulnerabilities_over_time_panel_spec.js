import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import VulnerabilitiesOverTimeChart from 'ee/security_dashboard/components/shared/charts/open_vulnerabilities_over_time.vue';
import GroupVulnerabilitiesOverTimePanel from 'ee/security_dashboard/components/shared/group_vulnerabilities_over_time_panel.vue';
import getVulnerabilitiesOverTime from 'ee/security_dashboard/graphql/queries/get_group_vulnerabilities_over_time.query.graphql';
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
      [getVulnerabilitiesOverTime, vulnerabilitiesOverTimeHandler],
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
  const findSeverityButton = () => wrapper.findByTestId('severity-button');
  const findReportTypeButton = () => wrapper.findByTestId('report-type-button');
  const findEmptyState = () => wrapper.findByTestId('vulnerabilities-over-time-empty-state');

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('passes the correct title to the panels base', () => {
      expect(findExtendedDashboardPanel().props('title')).toBe('Vulnerabilities over time');
    });

    it('renders the vulnerabilities over time chart when data is available', async () => {
      await waitForPromises();
      expect(findVulnerabilitiesOverTimeChart().exists()).toBe(true);
    });

    it('renders the group by buttons in the filters slot', () => {
      expect(findSeverityButton().text()).toBe('Severity');
      expect(findReportTypeButton().text()).toBe('Report Type');
    });

    it('sets severity button as selected by default', () => {
      expect(findSeverityButton().props('selected')).toBe(true);
      expect(findReportTypeButton().props('selected')).toBe(false);
    });
  });

  describe('group by functionality', () => {
    it('switches to report type grouping when report type button is clicked', async () => {
      await waitForPromises();
      const reportTypeButton = findReportTypeButton();

      await reportTypeButton.vm.$emit('click');
      await nextTick();

      expect(reportTypeButton.props('selected')).toBe(true);
      expect(findSeverityButton().props('selected')).toBe(false);
    });

    it('switches back to severity grouping when severity button is clicked', async () => {
      await waitForPromises();

      await findReportTypeButton().vm.$emit('click');
      await nextTick();

      await findSeverityButton().vm.$emit('click');
      await nextTick();

      expect(findSeverityButton().props('selected')).toBe(true);
      expect(findReportTypeButton().props('selected')).toBe(false);
    });
  });

  describe('Apollo query', () => {
    it('fetches vulnerabilities over time data when component is created', () => {
      const { vulnerabilitiesOverTimeHandler } = createComponent();

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith({
        fullPath: mockGroupFullPath,
        projectId: mockFilters.projectId,
        startDate: ninetyDaysAgoInIsoFormat,
        endDate: todayInIsoFormat,
        includeBySeverity: true,
        includeByReportType: false,
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

        expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith({
          fullPath: mockGroupFullPath,
          startDate: ninetyDaysAgoInIsoFormat,
          endDate: todayInIsoFormat,
          [availableFilterType]: ['filterValue'],
          includeBySeverity: true,
          includeByReportType: false,
        });
      },
    );

    it.each`
      condition                | filters
      ${'empty filters'}       | ${{}}
      ${'unsupported filters'} | ${{ unsupportedFilter: ['filterValue'] }}
    `('does not add filters to the GraphQL query when given $condition', ({ filters }) => {
      const { vulnerabilitiesOverTimeHandler } = createComponent({
        props: {
          filters,
        },
      });

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith({
        fullPath: mockGroupFullPath,
        startDate: ninetyDaysAgoInIsoFormat,
        endDate: todayInIsoFormat,
        includeBySeverity: true,
        includeByReportType: false,
      });
    });

    it('updates query variables when switching to report type grouping', async () => {
      const { vulnerabilitiesOverTimeHandler } = createComponent();

      await findReportTypeButton().vm.$emit('click');
      await waitForPromises();

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith({
        fullPath: mockGroupFullPath,
        projectId: mockFilters.projectId,
        startDate: ninetyDaysAgoInIsoFormat,
        endDate: todayInIsoFormat,
        includeBySeverity: false,
        includeByReportType: true,
      });
    });
  });

  describe('chart data formatting', () => {
    it('correctly formats chart data from the API response for severity grouping', async () => {
      await waitForPromises();
      await nextTick();

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

    it('correctly formats chart data from the API response for report type grouping', async () => {
      await findReportTypeButton().vm.$emit('click');
      await waitForPromises();
      await nextTick();

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

    it('passes the correct grouped-by prop for report type grouping', async () => {
      await findReportTypeButton().vm.$emit('click');
      await waitForPromises();
      await nextTick();

      expect(findVulnerabilitiesOverTimeChart().props('groupedBy')).toBe('reportType');
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
