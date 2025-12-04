import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlSprintf, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { helpPagePath } from '~/helpers/help_page_helper';
import SecurityDashboardDescription from 'ee/security_dashboard/components/shared/security_dashboard_description.vue';
import projectVulnerabilityManagementPolicies from 'ee/security_dashboard/graphql/queries/project_vulnerability_management_policies.query.graphql';
import groupVulnerabilityManagementPolicies from 'ee/security_dashboard/graphql/queries/group_vulnerability_management_policies.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

describe('SecurityDashboardDescription', () => {
  const defaultFullPath = 'gitlab-org';
  const defaultSecurityPoliciesPath = '/policies';
  const projectAutoResolveKey = 'project_security_dashboard_auto_resolve_alert';
  const projectNoLongerDetectedKey = 'project_security_dashboard_no_longer_detected_alert';

  let wrapper;
  let projectVulnerabilityManagementPoliciesHandler;
  let groupVulnerabilityManagementPoliciesHandler;

  const mockPoliciesData = {
    data: {
      namespace: {
        id: 'gid://gitlab/Group/1',
        vulnerabilityManagementPolicies: {
          nodes: [
            { __typename: 'VulnerabilityManagementPolicy' },
            { __typename: 'VulnerabilityManagementPolicy' },
          ],
        },
      },
    },
  };

  const mockEmptyPoliciesData = {
    data: {
      namespace: {
        id: 'gid://gitlab/Group/1',
        vulnerabilityManagementPolicies: {
          nodes: [],
        },
      },
    },
  };

  const createComponent = ({
    props = {},
    mockVulnerabilitiesHandler = null,
    scope = 'project',
  } = {}) => {
    projectVulnerabilityManagementPoliciesHandler = jest
      .fn()
      .mockResolvedValue(mockEmptyPoliciesData);
    groupVulnerabilityManagementPoliciesHandler = jest
      .fn()
      .mockResolvedValue(mockEmptyPoliciesData);

    // Override the handler for the specified scope if a custom one is provided
    if (mockVulnerabilitiesHandler) {
      if (scope === 'project') {
        projectVulnerabilityManagementPoliciesHandler = mockVulnerabilitiesHandler;
      } else {
        groupVulnerabilityManagementPoliciesHandler = mockVulnerabilitiesHandler;
      }
    }

    const apolloProvider = createMockApollo([
      [projectVulnerabilityManagementPolicies, projectVulnerabilityManagementPoliciesHandler],
      [groupVulnerabilityManagementPolicies, groupVulnerabilityManagementPoliciesHandler],
    ]);

    wrapper = shallowMountExtended(SecurityDashboardDescription, {
      apolloProvider,
      propsData: {
        scope,
        ...props,
      },
      provide: {
        fullPath: defaultFullPath,
        securityPoliciesPath: defaultSecurityPoliciesPath,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findGlLink = () => wrapper.findComponent(GlLink);
  const findAutoResolveAlert = () => wrapper.findByTestId('auto-resolve-alert');
  const findNoLongerDetectedAlert = () => wrapper.findByTestId('no-longer-detected-alert');

  beforeEach(() => {
    localStorage.clear();
  });

  describe('basic rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the correct description', () => {
      expect(wrapper.text()).toContain(
        'Panels that categorize vulnerabilities as open include those with Needs triage or Confirmed status. Hover over the info icon () to view more information about the data shown in each panel. To interact with a link in a chart popover, click to pin the popover first. To unstick it, click outside the popover. Learn more',
      );
    });

    it('renders the policy link with correct href', () => {
      const expectedHref = helpPagePath('user/application_security/security_dashboard/_index');

      expect(findGlLink().attributes('href')).toBe(expectedHref);
      expect(findGlLink().text()).toBe('Learn more');
    });
  });

  describe.each`
    alert                         | key                                              | findFn
    ${'auto resolve alert'}       | ${'security_dashboard_auto_resolve_alert'}       | ${findAutoResolveAlert}
    ${'no longer detected alert'} | ${'security_dashboard_no_longer_detected_alert'} | ${findNoLongerDetectedAlert}
  `(`${alert}`, ({ key, findFn }) => {
    it('does not show the alert while loading', () => {
      createComponent();

      expect(findFn().exists()).toBe(false);
    });

    it('does not show when dismissed before', () => {
      localStorage.setItem(`project_${key}`, true);
      createComponent();

      expect(findFn().exists()).toBe(false);
    });

    it('shows the alert when no policies exist', async () => {
      createComponent({
        mockVulnerabilitiesHandler: jest.fn().mockResolvedValue(mockEmptyPoliciesData),
      });
      await waitForPromises();

      expect(findFn().exists()).toBe(true);
    });

    it('hides the alert when dismissed', async () => {
      createComponent({
        mockVulnerabilitiesHandler: jest.fn().mockResolvedValue(mockEmptyPoliciesData),
      });
      await waitForPromises();

      findFn().vm.$emit('dismiss');
      await waitForPromises();

      expect(findFn().exists()).toBe(false);
      expect(localStorage.getItem(`project_${key}`)).toBe('true');
    });

    it('hides the alert when dismissed for group-level', async () => {
      createComponent({
        mockVulnerabilitiesHandler: jest.fn().mockResolvedValue(mockEmptyPoliciesData),
        scope: 'group',
      });
      await waitForPromises();

      findFn().vm.$emit('dismiss');
      await waitForPromises();

      expect(findFn().exists()).toBe(false);
      expect(localStorage.getItem(`group_${key}`)).toBe('true');
    });

    it('does not show the alert when policies exist', async () => {
      createComponent({
        mockVulnerabilitiesHandler: jest.fn().mockResolvedValue(mockPoliciesData),
      });

      await waitForPromises();

      expect(findFn().exists()).toBe(false);
    });
  });

  describe('auto resolve alert properties', () => {
    beforeEach(async () => {
      createComponent({
        mockVulnerabilitiesHandler: jest.fn().mockResolvedValue(mockEmptyPoliciesData),
      });

      await waitForPromises();
    });

    it('has the correct title', () => {
      expect(findAutoResolveAlert().props('title')).toBe(
        'Recommendation: Auto-resolve when no longer detected',
      );
    });

    it('has the correct primary button text', () => {
      expect(findAutoResolveAlert().props('primaryButtonText')).toBe('Go to policies');
    });

    it('has the correct primary button link', () => {
      expect(findAutoResolveAlert().props('primaryButtonLink')).toBe(defaultSecurityPoliciesPath);
    });

    it('displays the correct alert message', () => {
      expect(findAutoResolveAlert().text()).toContain(
        'To ensure that open vulnerabilities include only vulnerabilities that are still detected, use a vulnerability management policy to automatically resolve vulnerabilities that are no longer detected.',
      );
    });
  });

  describe('no longer detected alert properties', () => {
    beforeEach(async () => {
      createComponent({
        mockVulnerabilitiesHandler: jest.fn().mockResolvedValue(mockEmptyPoliciesData),
      });

      await waitForPromises();
    });

    it('displays the correct alert message', () => {
      expect(findNoLongerDetectedAlert().text()).toBe(
        'The vulnerabilities over time chart includes vulnerabilities that are no longer detected and might include more vulnerabilities than the totals shown in the counts per severity or in the vulnerability report.',
      );
    });
  });

  describe('Apollo query', () => {
    it('if scope if project', async () => {
      createComponent();
      await waitForPromises();

      expect(projectVulnerabilityManagementPoliciesHandler).toHaveBeenCalledWith({
        fullPath: defaultFullPath,
        relationship: 'INHERITED',
      });
      expect(groupVulnerabilityManagementPoliciesHandler).not.toHaveBeenCalled();
    });

    it('if scope if group', async () => {
      createComponent({ scope: 'group' });
      await waitForPromises();

      expect(groupVulnerabilityManagementPoliciesHandler).toHaveBeenCalledWith({
        fullPath: defaultFullPath,
        relationship: 'INHERITED',
      });
      expect(projectVulnerabilityManagementPoliciesHandler).not.toHaveBeenCalled();
    });

    it('does not call query if both alerts were dismissed', async () => {
      localStorage.setItem(projectAutoResolveKey, 'true');
      localStorage.setItem(projectNoLongerDetectedKey, 'true');
      createComponent();
      await waitForPromises();

      expect(groupVulnerabilityManagementPoliciesHandler).not.toHaveBeenCalled();
      expect(projectVulnerabilityManagementPoliciesHandler).not.toHaveBeenCalled();
    });
  });
});
