import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import VulnerabilitiesForSeverityPanel from 'ee/security_dashboard/components/shared/charts/vulnerabilities_for_severity_panel.vue';
import ProjectVulnerabilitiesForSeverityPanel from 'ee/security_dashboard/components/shared/project_vulnerabilities_for_severity_panel.vue';
import vulnerabilitiesPerSeverity from 'ee/security_dashboard/graphql/queries/project_vulnerabilities_per_severity.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('ProjectVulnerabilitiesForSeverityPanel', () => {
  let wrapper;
  let vulnerabilitiesPerSeverityHandler;

  const mockProjectFullPath = 'group/project';
  const mockFilters = { reportType: ['SAST'] };
  const defaultProps = {
    severity: 'medium',
    filters: mockFilters,
  };

  const defaultMockVulnerabilitiesPerSeverityData = {
    data: {
      project: {
        id: 'gid://gitlab/Project/1',
        securityMetrics: {
          vulnerabilitiesPerSeverity: {
            critical: { count: 3, __typename: 'VulnerabilitySeverityCount' },
            high: { count: 5, __typename: 'VulnerabilitySeverityCount' },
            medium: { count: 8, __typename: 'VulnerabilitySeverityCount' },
            low: { count: 10, __typename: 'VulnerabilitySeverityCount' },
            unknown: { count: 5, __typename: 'VulnerabilitySeverityCount' },
            info: { count: 3, __typename: 'VulnerabilitySeverityCount' },
            __typename: 'VulnerabilitiesPerSeverity',
          },
          __typename: 'SecurityMetrics',
        },
        __typename: 'Project',
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

    wrapper = shallowMountExtended(ProjectVulnerabilitiesForSeverityPanel, {
      apolloProvider,
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        projectFullPath: mockProjectFullPath,
        securityVulnerabilitiesPath: '/project/security/vulnerabilities',
      },
    });
  };

  const findVulnerabilitiesForSeverityPanel = () =>
    wrapper.findComponent(VulnerabilitiesForSeverityPanel);

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the vulnerabilities for severity panel', () => {
      expect(findVulnerabilitiesForSeverityPanel().exists()).toBe(true);
    });

    it('passes the correct props to the panel', () => {
      expect(findVulnerabilitiesForSeverityPanel().props()).toMatchObject({
        severity: defaultProps.severity,
        filters: defaultProps.filters,
      });
    });

    it('passes the count based on the data', async () => {
      const {
        medium: { count },
      } =
        defaultMockVulnerabilitiesPerSeverityData.data.project.securityMetrics
          .vulnerabilitiesPerSeverity;

      await waitForPromises();

      expect(findVulnerabilitiesForSeverityPanel().props('count')).toBe(count);
    });

    it('passes loading state to panels base', async () => {
      expect(findVulnerabilitiesForSeverityPanel().props('loading')).toBe(true);

      await waitForPromises();

      expect(findVulnerabilitiesForSeverityPanel().props('loading')).toBe(false);
    });
  });

  describe('Apollo query', () => {
    it('fetches vulnerabilities per severity data when component is created', () => {
      createComponent();

      expect(vulnerabilitiesPerSeverityHandler).toHaveBeenCalledWith({
        fullPath: mockProjectFullPath,
        reportType: mockFilters.reportType,
      });
    });

    it('passes reportType filter to the GraphQL query', () => {
      createComponent({
        props: {
          filters: { reportType: ['filterValue'] },
        },
      });

      expect(vulnerabilitiesPerSeverityHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          reportType: ['filterValue'],
        }),
      );
    });

    it('does not add unsupported filters that are passed', () => {
      createComponent({
        props: {
          filters: { projectId: ['filterValue'] },
        },
      });

      expect(vulnerabilitiesPerSeverityHandler).not.toHaveBeenCalledWith(
        expect.objectContaining({
          projectId: ['filterValue'],
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
