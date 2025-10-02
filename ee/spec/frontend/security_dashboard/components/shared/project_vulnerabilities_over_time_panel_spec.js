import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import VulnerabilitiesOverTimeChart from 'ee/security_dashboard/components/shared/charts/open_vulnerabilities_over_time.vue';
import ProjectVulnerabilitiesOverTimePanel from 'ee/security_dashboard/components/shared/project_vulnerabilities_over_time_panel.vue';
import OverTimeGroupBy from 'ee/security_dashboard/components/shared/over_time_group_by.vue';
import OverTimeSeverityFilter from 'ee/security_dashboard/components/shared/over_time_severity_filter.vue';
import OverTimePeriodSelector from 'ee/security_dashboard/components/shared/over_time_period_selector.vue';
import projectVulnerabilitiesOverTime from 'ee/security_dashboard/graphql/queries/project_vulnerabilities_over_time.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useFakeDate } from 'helpers/fake_date';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('ProjectVulnerabilitiesOverTimePanel', () => {
  const todayInIsoFormat = '2022-07-06';
  const thirtyDaysAgoInIsoFormat = '2022-06-06';
  useFakeDate(todayInIsoFormat);

  let wrapper;

  const mockProjectFullPath = 'project-1';
  const mockFilters = { reportType: ['API_FUZZING'] };

  const createMockData = () => ({
    data: {
      project: {
        id: 'gid://gitlab/Project/1',
        securityMetrics: {
          vulnerabilitiesOverTime: {
            nodes: [
              {
                date: '2022-06-01',
                bySeverity: [
                  { severity: 'CRITICAL', count: 3 },
                  { severity: 'HIGH', count: 7 },
                ],
                byReportType: [{ reportType: 'API_FUZZING', count: 5 }],
              },
            ],
          },
        },
      },
    },
  });

  const createComponent = ({ props = {}, mockVulnerabilitiesOverTimeHandler = null } = {}) => {
    const defaultMockData = createMockData();
    const vulnerabilitiesOverTimeHandler =
      mockVulnerabilitiesOverTimeHandler || jest.fn().mockResolvedValue(defaultMockData);

    const apolloProvider = createMockApollo([
      [projectVulnerabilitiesOverTime, vulnerabilitiesOverTimeHandler],
    ]);

    wrapper = shallowMountExtended(ProjectVulnerabilitiesOverTimePanel, {
      apolloProvider,
      propsData: {
        filters: mockFilters,
        ...props,
      },
      provide: {
        projectFullPath: mockProjectFullPath,
      },
    });

    return { vulnerabilitiesOverTimeHandler };
  };

  const findExtendedDashboardPanel = () => wrapper.findComponent(ExtendedDashboardPanel);
  const findVulnerabilitiesOverTimeChart = () =>
    wrapper.findComponent(VulnerabilitiesOverTimeChart);
  const findOverTimeGroupBy = () => wrapper.findComponent(OverTimeGroupBy);
  const findOverTimePeriodSelector = () => wrapper.findComponent(OverTimePeriodSelector);
  const findSeverityFilter = () => wrapper.findComponent(OverTimeSeverityFilter);
  const findEmptyState = () => wrapper.findByTestId('vulnerabilities-over-time-empty-state');

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('passes the correct title to the panels base', () => {
      expect(findExtendedDashboardPanel().props('title')).toBe('Vulnerabilities over time');
    });

    it('passes the correct tooltip to the panels base', () => {
      expect(findExtendedDashboardPanel().props('tooltip')).toEqual({
        description: 'Vulnerability trends over time',
      });
    });

    it('renders the vulnerabilities over time chart when data is available', async () => {
      await waitForPromises();
      expect(findVulnerabilitiesOverTimeChart().exists()).toBe(true);
    });

    it('passes severity value to OverTimeGroupBy by default', () => {
      expect(findOverTimeGroupBy().props('value')).toBe('severity');
    });

    it('renders all filter components', () => {
      expect(findOverTimePeriodSelector().exists()).toBe(true);
      expect(findSeverityFilter().exists()).toBe(true);
      expect(findOverTimeGroupBy().exists()).toBe(true);
    });

    it('sets initial time period for the chart data to 30 days', () => {
      expect(findOverTimePeriodSelector().props('value')).toBe(30);
    });
  });

  describe('data fetching', () => {
    it('fetches data with correct variables for project namespace', async () => {
      const { vulnerabilitiesOverTimeHandler } = createComponent();
      await waitForPromises();

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith({
        fullPath: mockProjectFullPath,
        reportType: mockFilters.reportType,
        severity: [],
        includeBySeverity: true,
        includeByReportType: false,
        startDate: thirtyDaysAgoInIsoFormat,
        endDate: todayInIsoFormat,
      });
    });

    it('does not include projectId in query variables for projects', async () => {
      const { vulnerabilitiesOverTimeHandler } = createComponent();
      await waitForPromises();

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith(
        expect.not.objectContaining({
          projectId: expect.anything(),
        }),
      );
    });

    it('re-fetches data when time period changes', async () => {
      const { vulnerabilitiesOverTimeHandler } = createComponent();
      await waitForPromises();

      const initialCallCount = vulnerabilitiesOverTimeHandler.mock.calls.length;

      await findOverTimePeriodSelector().vm.$emit('input', 60);
      await waitForPromises();

      expect(vulnerabilitiesOverTimeHandler.mock.calls.length).toBeGreaterThan(initialCallCount);
    });
  });

  describe('time period selection', () => {
    const sixtyDaysAgoInIsoFormat = '2022-05-07';
    const thirtyOneDaysAgoInIsoFormat = '2022-06-05';
    const ninetyDaysAgoInIsoFormat = '2022-04-07';
    const sixtyOneDaysAgoInIsoFormat = '2022-05-06';

    it('fetches only 30-day chunk for default period', async () => {
      const { vulnerabilitiesOverTimeHandler } = createComponent();
      await waitForPromises();

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledTimes(1);
      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith({
        fullPath: mockProjectFullPath,
        reportType: mockFilters.reportType,
        severity: [],
        includeBySeverity: true,
        includeByReportType: false,
        startDate: thirtyDaysAgoInIsoFormat,
        endDate: todayInIsoFormat,
      });
    });

    it('fetches 30-day and 60-day chunks when period is set to 60', async () => {
      const { vulnerabilitiesOverTimeHandler } = createComponent();

      await findOverTimePeriodSelector().vm.$emit('input', 60);
      await waitForPromises();

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledTimes(2);

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          startDate: thirtyDaysAgoInIsoFormat,
          endDate: todayInIsoFormat,
        }),
      );

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          startDate: sixtyDaysAgoInIsoFormat,
          endDate: thirtyOneDaysAgoInIsoFormat,
        }),
      );
    });

    it('fetches all three chunks when period is set to 90', async () => {
      const { vulnerabilitiesOverTimeHandler } = createComponent();

      await findOverTimePeriodSelector().vm.$emit('input', 90);
      await waitForPromises();

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledTimes(3);

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          startDate: thirtyDaysAgoInIsoFormat,
          endDate: todayInIsoFormat,
        }),
      );

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          startDate: sixtyDaysAgoInIsoFormat,
          endDate: thirtyOneDaysAgoInIsoFormat,
        }),
      );

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          startDate: ninetyDaysAgoInIsoFormat,
          endDate: sixtyOneDaysAgoInIsoFormat,
        }),
      );
    });
  });

  describe('filters', () => {
    it('updates GraphQL query when severity filter changes', async () => {
      const { vulnerabilitiesOverTimeHandler } = createComponent();
      const appliedFilters = ['CRITICAL', 'HIGH'];

      await waitForPromises();
      const initialCallCount = vulnerabilitiesOverTimeHandler.mock.calls.length;

      await findSeverityFilter().vm.$emit('input', appliedFilters);
      await waitForPromises();

      expect(vulnerabilitiesOverTimeHandler.mock.calls.length).toBeGreaterThan(initialCallCount);
      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          severity: appliedFilters,
        }),
      );
    });
  });

  describe('loading state', () => {
    it('shows loading state initially', () => {
      createComponent();

      expect(findExtendedDashboardPanel().props('loading')).toBe(true);
    });

    it('hides loading state after data is loaded', async () => {
      createComponent();
      await waitForPromises();

      expect(findExtendedDashboardPanel().props('loading')).toBe(false);
    });

    it('shows loading state when switching time periods', async () => {
      createComponent();
      await waitForPromises();

      expect(findExtendedDashboardPanel().props('loading')).toBe(false);

      await findOverTimePeriodSelector().vm.$emit('input', 60);

      expect(findExtendedDashboardPanel().props('loading')).toBe(true);

      await waitForPromises();

      expect(findExtendedDashboardPanel().props('loading')).toBe(false);
    });
  });

  describe('error handling', () => {
    it('shows error state when GraphQL query fails', async () => {
      createComponent({
        mockVulnerabilitiesOverTimeHandler: jest.fn().mockRejectedValue(new Error('GraphQL error')),
      });

      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(true);
      expect(findVulnerabilitiesOverTimeChart().exists()).toBe(false);
      expect(findEmptyState().text()).toBe('Something went wrong. Please try again.');
    });

    it('shows error state when server returns error response', async () => {
      createComponent({
        mockVulnerabilitiesOverTimeHandler: jest.fn().mockResolvedValue({
          errors: [{ message: 'Internal server error' }],
        }),
      });

      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(true);
      expect(findVulnerabilitiesOverTimeChart().exists()).toBe(false);
      expect(findEmptyState().text()).toBe('Something went wrong. Please try again.');
    });

    it('handles error when switching time periods', async () => {
      const mockHandler = jest
        .fn()
        .mockResolvedValueOnce(createMockData())
        .mockRejectedValueOnce(new Error('Network error'));

      createComponent({
        mockVulnerabilitiesOverTimeHandler: mockHandler,
      });

      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(false);
      expect(findVulnerabilitiesOverTimeChart().exists()).toBe(true);

      await findOverTimePeriodSelector().vm.$emit('input', 60);
      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(true);
      expect(findVulnerabilitiesOverTimeChart().exists()).toBe(false);
      expect(findEmptyState().text()).toBe('Something went wrong. Please try again.');
    });

    it('handles partial chunk failures gracefully', async () => {
      const mockHandler = jest
        .fn()
        .mockResolvedValueOnce(createMockData())
        .mockRejectedValueOnce(new Error('Network timeout'));

      createComponent({
        mockVulnerabilitiesOverTimeHandler: mockHandler,
      });

      await findOverTimePeriodSelector().vm.$emit('input', 60);
      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(true);
      expect(findVulnerabilitiesOverTimeChart().exists()).toBe(false);
      expect(findEmptyState().text()).toBe('Something went wrong. Please try again.');
    });

    it('handles error during filter changes', async () => {
      const mockHandler = jest
        .fn()
        .mockResolvedValueOnce(createMockData())
        .mockRejectedValueOnce(new Error('Filter error'));

      createComponent({
        mockVulnerabilitiesOverTimeHandler: mockHandler,
      });

      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(false);

      await findSeverityFilter().vm.$emit('input', ['CRITICAL']);
      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(true);
      expect(findVulnerabilitiesOverTimeChart().exists()).toBe(false);
    });

    it('resets error state when retrying after successful data fetch', async () => {
      const mockHandler = jest
        .fn()
        .mockRejectedValueOnce(new Error('Initial error'))
        .mockResolvedValue(createMockData());

      createComponent({
        mockVulnerabilitiesOverTimeHandler: mockHandler,
      });

      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(true);
      expect(findVulnerabilitiesOverTimeChart().exists()).toBe(false);

      await findOverTimePeriodSelector().vm.$emit('input', 60);
      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(false);
      expect(findVulnerabilitiesOverTimeChart().exists()).toBe(true);
    });
  });
});
