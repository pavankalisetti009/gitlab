import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlSprintf, GlLink, GlAlert } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
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
  const projectKey = 'project_security_dashboard_auto_resolve_alert';
  const groupKey = 'group_security_dashboard_auto_resolve_alert';
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

    wrapper = shallowMount(SecurityDashboardDescription, {
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
  const findGlAlert = () => wrapper.findComponent(GlAlert);

  beforeEach(() => {
    localStorage.clear();
  });

  describe('basic rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the correct description', () => {
      expect(wrapper.text()).toBe(
        'Panels that categorize vulnerabilities as open include those with Needs triage or Confirmed status. To interact with a link in a chart popover, click to pin the popover first. To unstick it, click outside the popover. Learn more',
      );
    });

    it('renders the policy link with correct href', () => {
      const expectedHref = helpPagePath('user/application_security/security_dashboard/_index');

      expect(findGlLink().attributes('href')).toBe(expectedHref);
      expect(findGlLink().text()).toBe('Learn more');
    });
  });

  describe('auto-resolve alert', () => {
    it('does not show the alert while loading', () => {
      createComponent();

      expect(findGlAlert().exists()).toBe(false);
    });

    it('shows the alert when no policies exist', async () => {
      createComponent({
        mockVulnerabilitiesHandler: jest.fn().mockResolvedValue(mockEmptyPoliciesData),
      });
      await waitForPromises();

      expect(findGlAlert().exists()).toBe(true);
    });

    it('hides the alert when dismissed', async () => {
      createComponent({
        mockVulnerabilitiesHandler: jest.fn().mockResolvedValue(mockEmptyPoliciesData),
      });
      await waitForPromises();

      findGlAlert().vm.$emit('dismiss');
      await waitForPromises();

      expect(findGlAlert().exists()).toBe(false);
      expect(localStorage.getItem(projectKey)).toBe('true');
    });

    it('hides the alert when dismissed for group-level', async () => {
      createComponent({
        mockVulnerabilitiesHandler: jest.fn().mockResolvedValue(mockEmptyPoliciesData),
        scope: 'group',
      });
      await waitForPromises();

      findGlAlert().vm.$emit('dismiss');
      await waitForPromises();

      expect(findGlAlert().exists()).toBe(false);
      expect(localStorage.getItem(groupKey)).toBe('true');
    });

    it('does not show the alert when policies exist', async () => {
      createComponent({
        mockVulnerabilitiesHandler: jest.fn().mockResolvedValue(mockPoliciesData),
      });

      await waitForPromises();

      expect(findGlAlert().exists()).toBe(false);
    });

    describe('alert properties', () => {
      beforeEach(async () => {
        createComponent({
          mockVulnerabilitiesHandler: jest.fn().mockResolvedValue(mockEmptyPoliciesData),
        });

        await waitForPromises();
      });

      it('has the correct title', () => {
        expect(findGlAlert().props('title')).toBe(
          'Recommendation: Auto-resolve when no longer detected',
        );
      });

      it('has the correct primary button text', () => {
        expect(findGlAlert().props('primaryButtonText')).toBe('Go to Policies');
      });

      it('has the correct primary button link', () => {
        expect(findGlAlert().props('primaryButtonLink')).toBe(defaultSecurityPoliciesPath);
      });

      it('displays the correct alert message', () => {
        expect(findGlAlert().text()).toContain(
          'To ensure that open vulnerabilities only include vulnerabilities that are still detected, we recommend enabling the policy to auto-resolve vulnerabilities when no longer detected.',
        );
      });
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

    it('does not call query if banner was dismissed', async () => {
      localStorage.setItem(projectKey, 'true');
      createComponent();
      await waitForPromises();

      expect(groupVulnerabilityManagementPoliciesHandler).not.toHaveBeenCalled();
      expect(projectVulnerabilityManagementPoliciesHandler).not.toHaveBeenCalled();
    });
  });
});
