import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import VulnerabilitiesForSeverityPanel from 'ee/security_dashboard/components/shared/charts/vulnerabilities_for_severity_panel.vue';
import GroupVulnerabilitiesForSeverityPanel from 'ee/security_dashboard/components/shared/group_vulnerabilities_for_severity_panel.vue';
import vulnerabilitiesPerSeverity from 'ee/security_dashboard/graphql/queries/group_vulnerabilities_per_severity.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('GroupVulnerabilitiesForSeverityPanel', () => {
  let wrapper;
  let vulnerabilitiesPerSeverityHandler;

  const mockGroupFullPath = 'group/subgroup';
  const mockFilters = { projectId: 'gid://gitlab/Project/123' };
  const defaultProps = {
    severity: 'medium',
    filters: mockFilters,
  };

  const defaultMockVulnerabilitiesPerSeverityData = {
    data: {
      group: {
        id: 'gid://gitlab/Group/1',
        securityMetrics: {
          vulnerabilitiesPerSeverity: {
            critical: 3,
            high: 5,
            medium: 8,
            low: 10,
            unknown: 5,
            info: 3,
          },
        },
      },
    },
  };

  const createComponent = ({ props = {}, mockVulnerabilitiesPerSeverityHandler = null } = {}) => {
    vulnerabilitiesPerSeverityHandler =
      mockVulnerabilitiesPerSeverityHandler ||
      jest.fn().mockResolvedValue(defaultMockVulnerabilitiesPerSeverityData);

    const apolloProvider = createMockApollo([
      [vulnerabilitiesPerSeverity, vulnerabilitiesPerSeverityHandler],
    ]);

    wrapper = shallowMountExtended(GroupVulnerabilitiesForSeverityPanel, {
      apolloProvider,
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        groupFullPath: mockGroupFullPath,
        securityVulnerabilitiesPath: '/group/security/vulnerabilities',
      },
    });
  };

  const findVulnerabilitiesForSeverityPanel = () =>
    wrapper.findComponent(VulnerabilitiesForSeverityPanel);

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('renders the vulnerabilities for severity panel', () => {
      expect(findVulnerabilitiesForSeverityPanel().exists()).toBe(true);
    });

    it('passes the severity to the panel', () => {
      expect(findVulnerabilitiesForSeverityPanel().props('severity')).toBe('medium');
    });

    it('passes the filters to the panel', () => {
      expect(findVulnerabilitiesForSeverityPanel().props('filters')).toBe(defaultProps.filters);
    });

    it('passes the count based on the data', async () => {
      const { medium } =
        defaultMockVulnerabilitiesPerSeverityData.data.group.securityMetrics
          .vulnerabilitiesPerSeverity;
      await waitForPromises();
      expect(findVulnerabilitiesForSeverityPanel().props('count')).toBe(medium);
    });

    it('passes loading state to panels base', async () => {
      expect(findVulnerabilitiesForSeverityPanel().props('loading')).toBe(true);

      await waitForPromises();

      expect(findVulnerabilitiesForSeverityPanel().props('loading')).toBe(false);
    });
  });

  describe('Apollo query', () => {
    it('fetches vulnerabilities per severity data when component is created', () => {
      expect(vulnerabilitiesPerSeverityHandler).toHaveBeenCalledWith({
        fullPath: mockGroupFullPath,
        projectId: mockFilters.projectId,
        reportType: undefined,
      });
    });

    it.each(['projectId', 'reportType'])(
      'passes filters to the GraphQL query',
      (availableFilterType) => {
        createComponent({
          props: {
            filters: { [availableFilterType]: ['filterValue'] },
          },
        });

        expect(vulnerabilitiesPerSeverityHandler).toHaveBeenCalledWith(
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
      createComponent({
        props: {
          filters: { unsupportedFilter },
        },
      });

      expect(vulnerabilitiesPerSeverityHandler).not.toHaveBeenCalledWith(
        expect.objectContaining({
          unsupportedFilter,
        }),
      );
    });
  });

  describe('error handling', () => {
    describe.each`
      errorType                   | mockVulnerabilitiesPerSeverityHandler
      ${'GraphQL query failures'} | ${jest.fn().mockRejectedValue(new Error('GraphQL query failed'))}
      ${'server error responses'} | ${jest.fn().mockResolvedValue({ errors: [{ message: 'Internal server error' }] })}
    `('$errorType', ({ mockVulnerabilitiesPerSeverityHandler }) => {
      beforeEach(async () => {
        createComponent({
          mockVulnerabilitiesPerSeverityHandler,
        });

        await waitForPromises();
      });

      it('sets the panel error prop', () => {
        expect(findVulnerabilitiesForSeverityPanel().props('error')).toBe(true);
      });
    });
  });
});
