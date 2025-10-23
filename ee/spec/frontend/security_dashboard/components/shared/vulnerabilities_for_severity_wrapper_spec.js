import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import VulnerabilitiesForSeverityPanel from 'ee/security_dashboard/components/shared/charts/vulnerabilities_for_severity_panel.vue';
import VulnerabilitiesForSeverityWrapper from 'ee/security_dashboard/components/shared/vulnerabilities_for_severity_wrapper.vue';
import groupVulnerabilitiesPerSeverity from 'ee/security_dashboard/graphql/queries/group_vulnerabilities_per_severity.query.graphql';
import projectVulnerabilitiesPerSeverity from 'ee/security_dashboard/graphql/queries/project_vulnerabilities_per_severity.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('VulnerabilitiesForSeverityWrapper', () => {
  let wrapper;
  let vulnerabilitiesPerSeverityHandler;

  const securityMetrics = {
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
  };

  const scopeConfigs = {
    project: {
      scope: 'project',
      fullPath: 'project-1',
      query: projectVulnerabilitiesPerSeverity,
      filters: { reportType: ['API_FUZZING'] },
      expectedVariables: {
        fullPath: 'project-1',
        reportType: ['API_FUZZING'],
      },
      createMockData: () => ({
        data: {
          namespace: {
            id: 'gid://gitlab/Project/1',
            securityMetrics,
            __typename: 'Project',
          },
        },
      }),
    },
    group: {
      scope: 'group',
      fullPath: 'group/subgroup',
      query: groupVulnerabilitiesPerSeverity,
      filters: { projectId: 'gid://gitlab/Project/123', reportType: ['SAST'] },
      expectedVariables: {
        fullPath: 'group/subgroup',
        projectId: 'gid://gitlab/Project/123',
        reportType: ['SAST'],
      },
      createMockData: () => ({
        data: {
          namespace: {
            id: 'gid://gitlab/Group/1',
            securityMetrics,
            __typename: 'Group',
          },
        },
      }),
    },
  };

  const createComponent = ({
    scope = 'project',
    props = {},
    mockVulnerabilitiesPerSeverityHandler = null,
  } = {}) => {
    const config = scopeConfigs[scope];
    const defaultMockData = config.createMockData();
    vulnerabilitiesPerSeverityHandler =
      mockVulnerabilitiesPerSeverityHandler || jest.fn().mockResolvedValue(defaultMockData);

    const apolloProvider = createMockApollo([[config.query, vulnerabilitiesPerSeverityHandler]]);

    wrapper = shallowMountExtended(VulnerabilitiesForSeverityWrapper, {
      apolloProvider,
      propsData: {
        scope: config.scope,
        filters: config.filters,
        severity: 'medium',
        ...props,
      },
      provide: {
        fullPath: config.fullPath,
        securityVulnerabilitiesPath: '/group/security/vulnerabilities',
      },
    });

    return { config };
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
      const { config } = createComponent();
      expect(findVulnerabilitiesForSeverityPanel().props('filters')).toBe(config.filters);
    });

    it('passes the count based on the data', async () => {
      const { config } = createComponent();
      const { medium } =
        config.createMockData().data.namespace.securityMetrics.vulnerabilitiesPerSeverity;
      await waitForPromises();

      expect(findVulnerabilitiesForSeverityPanel().props('count')).toBe(medium.count);
    });

    it('passes loading state to panels base', async () => {
      expect(findVulnerabilitiesForSeverityPanel().props('loading')).toBe(true);

      await waitForPromises();

      expect(findVulnerabilitiesForSeverityPanel().props('loading')).toBe(false);
    });
  });

  describe('Apollo query', () => {
    it('fetches vulnerabilities per severity data when component is created', () => {
      const { config } = createComponent();
      expect(vulnerabilitiesPerSeverityHandler).toHaveBeenCalledWith(config.expectedVariables);
    });

    describe.each(['project', 'group'])('when scope is "%s"', (scopeType) => {
      it('vulnerabilities per severity data when component is created', async () => {
        const { config } = createComponent({ scope: scopeType });
        await waitForPromises();

        expect(vulnerabilitiesPerSeverityHandler).toHaveBeenCalledWith({
          ...config.expectedVariables,
        });
      });
    });

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
