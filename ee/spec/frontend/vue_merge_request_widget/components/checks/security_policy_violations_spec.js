import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import SecurityPolicyViolations from 'ee/vue_merge_request_widget/components/checks/security_policy_violations.vue';
import SecurityPolicyViolationsModal from 'ee/vue_merge_request_widget/components/checks/security_policy_violations_modal.vue';
import ActionButtons from '~/vue_merge_request_widget/components/action_buttons.vue';
import getPolicyViolations from 'ee/merge_requests/reports/queries/policy_violations.query.graphql';
import { WARN_MODE, EXCEPTION_MODE } from 'ee/vue_merge_request_widget/components/checks/constants';
import {
  mockEnforcedSecurityPolicyViolation,
  mockWarnSecurityPolicyViolation,
} from '../../mock_data';

Vue.use(VueApollo);

const getApolloProvider = (policies) =>
  createMockApollo(
    [
      [
        getPolicyViolations,
        jest.fn().mockResolvedValue({
          data: {
            project: {
              id: 'gid://gitlab/Project/25',
              mergeRequest: {
                id: 'gid://gitlab/MergeRequest/598',
                targetBranch: 'main',
                sourceBranch: 'root-main-patch-82768',
                headPipeline: {
                  id: 'gid://gitlab/Ci::Pipeline/101891',
                  iid: '19776',
                  updatedAt: '2025-08-20T22:13:19Z',
                  path: '/gitlab-org/security-reports/-/pipelines/101891',
                  __typename: 'Pipeline',
                },
                policyViolations: {
                  comparisonPipelines: [],
                  anyMergeRequest: [],
                  licenseScanning: [],
                  newScanFinding: [],
                  policies,
                  previousScanFinding: [],
                  __typename: 'PolicyViolationDetails',
                },
                __typename: 'MergeRequest',
              },
              __typename: 'Project',
            },
          },
        }),
      ],
    ],
    {},
    { typePolicies: { Query: { fields: { project: { merge: false } } } } },
  );

describe('SecurityPolicyViolations merge checks component', () => {
  let wrapper;
  const policiesPath = '/security-path';

  function createComponent({
    allowBypass = false,
    status = 'SUCCESS',
    securityPoliciesPath = null,
    warnModeEnabled = false,
    securityPoliciesBypassOptionsMrWidget = false,
    policies = [
      mockEnforcedSecurityPolicyViolation,
      mockWarnSecurityPolicyViolation,
      mockWarnSecurityPolicyViolation,
    ],
  } = {}) {
    wrapper = mountExtended(SecurityPolicyViolations, {
      apolloProvider: getApolloProvider(policies),
      propsData: {
        mr: {
          allowBypass,
          securityPoliciesPath,
          iid: 123,
          targetProjectFullPath: 'group/project',
        },
        check: {
          identifier: 'security_policy_violations',
          status,
        },
      },
      provide: {
        glFeatures: {
          securityPolicyApprovalWarnMode: warnModeEnabled,
          securityPoliciesBypassOptionsMrWidget,
        },
      },
      stubs: { ActionButtons },
    });
  }

  const findActionLink = () => wrapper.findByTestId('view-policies-button');
  const findBypassButton = () => wrapper.findByTestId('bypass-button');
  const findIcon = () => wrapper.findByTestId('security-policy-help-icon');
  const findModal = () => wrapper.findComponent(SecurityPolicyViolationsModal);
  const findPopover = () => wrapper.findByTestId('security-policy-help-popover');
  const findViewPoliciesLink = () => wrapper.find('[href="/security-path"]');

  describe('action buttons', () => {
    it.each`
      status        | path            | exists   | rendersText
      ${'SUCCESS'}  | ${policiesPath} | ${true}  | ${'renders'}
      ${'SUCCESS'}  | ${''}           | ${false} | ${'does not render'}
      ${'SUCCESS'}  | ${null}         | ${false} | ${'does not render'}
      ${'FAILED'}   | ${policiesPath} | ${true}  | ${'renders'}
      ${'FAILED'}   | ${''}           | ${false} | ${'does not render'}
      ${'FAILED'}   | ${null}         | ${false} | ${'does not render'}
      ${'INACTIVE'} | ${policiesPath} | ${false} | ${'does not render'}
      ${'INACTIVE'} | ${''}           | ${false} | ${'does not render'}
      ${'INACTIVE'} | ${null}         | ${false} | ${'does not render'}
    `(
      '$rendersText link to security policies when status is $status',
      ({ status, path, exists }) => {
        createComponent({ status, securityPoliciesPath: path });

        expect(findActionLink().exists()).toBe(exists);

        if (exists) {
          expect(findActionLink().attributes('href')).toBe(path);
        }
      },
    );

    it('renders View policies link when securityPoliciesPath is provided', () => {
      createComponent({ securityPoliciesPath: policiesPath });

      expect(findViewPoliciesLink().exists()).toBe(true);
      expect(findViewPoliciesLink().attributes('href')).toBe(policiesPath);
      expect(findViewPoliciesLink().text()).toBe('View policies');
    });
  });

  describe('bypass functionality', () => {
    it.each`
      title                                                                                       | warnModeEnabled | securityPoliciesPath | policies
      ${'warn mode is disabled and there is not a security path and there are no policies'}       | ${false}        | ${''}                | ${[]}
      ${'warn mode is disabled and there is not a security path and there are enforced policies'} | ${false}        | ${''}                | ${[mockEnforcedSecurityPolicyViolation]}
      ${'warn mode is disabled and there is not a security path and there are warn policies'}     | ${false}        | ${''}                | ${[mockWarnSecurityPolicyViolation]}
      ${'warn mode is disabled and there is a security path and there are no policies'}           | ${false}        | ${policiesPath}      | ${[]}
      ${'warn mode is disabled and there is a security path adn there are enforced policies'}     | ${false}        | ${policiesPath}      | ${[mockEnforcedSecurityPolicyViolation]}
      ${'warn mode is disabled and there is a security path adn there are warn policies'}         | ${false}        | ${policiesPath}      | ${[mockWarnSecurityPolicyViolation]}
      ${'warn mode is enabled and this is no security path and there are no policies'}            | ${true}         | ${''}                | ${[]}
      ${'warn mode is enabled and this is no security path and there are enforced policies'}      | ${true}         | ${''}                | ${[mockEnforcedSecurityPolicyViolation]}
      ${'warn mode is enabled and this is no security path and there are warn policies'}          | ${true}         | ${''}                | ${[mockWarnSecurityPolicyViolation]}
      ${'warn mode is enabled and this is is a security path and there are no policies'}          | ${true}         | ${policiesPath}      | ${[]}
      ${'warn mode is enabled and this is is a security path and there are enforced policies'}    | ${true}         | ${policiesPath}      | ${[mockEnforcedSecurityPolicyViolation]}
    `(
      'does not show the bypass button when $title',
      async ({ warnModeEnabled, securityPoliciesPath, policies }) => {
        createComponent({
          warnModeEnabled,
          securityPoliciesPath,
          policies,
        });
        await waitForPromises();

        expect(findBypassButton().exists()).toBe(false);
      },
    );

    it.each`
      policiesTitle                                             | warnModeEnabled | securityPoliciesPath | policies
      ${'there are warn policies that have not been dismissed'} | ${true}         | ${policiesPath}      | ${[mockWarnSecurityPolicyViolation]}
      ${'there are warn policies that have been dismissed'}     | ${true}         | ${policiesPath}      | ${[{ ...mockWarnSecurityPolicyViolation, dismissed: true }]}
    `(
      'shows the bypass button when warn mode is enabled and there is a security path and $policiesTitle',
      async ({ warnModeEnabled, securityPoliciesPath, policies }) => {
        createComponent({
          warnModeEnabled,
          securityPoliciesPath,
          policies,
        });
        await waitForPromises();

        expect(findBypassButton().exists()).toBe(true);
      },
    );

    it('does not disable the bypass button if all warn policies have been dismissed', async () => {
      createComponent({
        warnModeEnabled: true,
        securityPoliciesPath: policiesPath,
        policies: [mockWarnSecurityPolicyViolation],
      });
      await waitForPromises();

      expect(findBypassButton().props('disabled')).toBe(false);
    });

    it('disables the bypass button if all warn policies have been dismissed', async () => {
      createComponent({
        warnModeEnabled: true,
        securityPoliciesPath: policiesPath,
        policies: [{ ...mockWarnSecurityPolicyViolation, dismissed: true }],
      });
      await waitForPromises();

      expect(findBypassButton().props('disabled')).toBe(true);
    });

    it('shows info icon with popover', async () => {
      await createComponent({
        warnModeEnabled: true,
        securityPoliciesPath: policiesPath,
      });
      await waitForPromises();

      expect(findIcon().exists()).toBe(true);
      expect(findPopover().exists()).toBe(true);
    });

    it('opens modal when bypass button is clicked', async () => {
      const securityPoliciesPath = policiesPath;
      createComponent({
        warnModeEnabled: true,
        securityPoliciesPath,
      });
      await waitForPromises();

      expect(findModal().exists()).toBe(false);

      await findBypassButton().vm.$emit('click');

      expect(findModal().exists()).toBe(true);
      expect(findModal().props()).toEqual(
        expect.objectContaining({
          mode: WARN_MODE,
          mr: {
            allowBypass: false,
            securityPoliciesPath,
            iid: 123,
            targetProjectFullPath: 'group/project',
          },
          policies: [mockWarnSecurityPolicyViolation],
        }),
      );
    });

    it('closes modal when close event is emitted', async () => {
      createComponent({
        warnModeEnabled: true,
        securityPoliciesPath: policiesPath,
      });
      await waitForPromises();

      await findBypassButton().vm.$emit('click');
      expect(findModal().exists()).toBe(true);

      await findModal().vm.$emit('close');

      expect(findModal().exists()).toBe(false);
    });

    it('selects the mode for bypass options', async () => {
      createComponent({
        warnModeEnabled: true,
        securityPoliciesPath: policiesPath,
      });
      await waitForPromises();

      await findBypassButton().vm.$emit('click');

      await findModal().vm.$emit('select-mode', EXCEPTION_MODE);

      expect(findModal().props('mode')).toBe(EXCEPTION_MODE);
    });

    it('enables mode selector when there is a conflict', async () => {
      createComponent({
        securityPoliciesBypassOptionsMrWidget: true,
        allowBypass: true,
        securityPoliciesPath: policiesPath,
        warnModeEnabled: true,
      });
      await waitForPromises();

      await findBypassButton().vm.$emit('click');

      expect(findModal().props('mode')).toBe('');
    });
  });
});
