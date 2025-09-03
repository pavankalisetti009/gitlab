import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import SecurityPolicyViolations from 'ee/vue_merge_request_widget/components/checks/security_policy_violations.vue';
import SecurityPolicyViolationsModal from 'ee/vue_merge_request_widget/components/checks/security_policy_violations_modal.vue';
import ActionButtons from '~/vue_merge_request_widget/components/action_buttons.vue';
import getPolicyViolations from 'ee/merge_requests/reports/queries/policy_violations.query.graphql';

Vue.use(VueApollo);

const mockPolicies = [
  {
    name: 'Warn mode - 01',
    reportType: 'ANY_MERGE_REQUEST',
    status: 'FAILED',
    __typename: 'PolicyViolationInfo',
  },
  {
    name: 'Prevent Critical Vulnerabilities',
    reportType: 'SCAN_FINDING',
    status: 'FAILED',
    __typename: 'PolicyViolationInfo',
  },
];

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

  const findActionLink = () => wrapper.findByTestId('view-policies-button');
  const findBypassButton = () => wrapper.findByTestId('bypass-button');
  const findViewPoliciesLink = () => wrapper.find('[href="/security-path"]');
  const findModal = () => wrapper.findComponent(SecurityPolicyViolationsModal);

  function createComponent({
    status = 'SUCCESS',
    securityPoliciesPath = null,
    warnModeEnabled = false,
    policies = mockPolicies,
  } = {}) {
    wrapper = mountExtended(SecurityPolicyViolations, {
      apolloProvider: getApolloProvider(policies),
      propsData: {
        mr: {
          securityPoliciesPath,
          iid: 123,
          targetProjectFullPath: 'group/project',
        },
        check: {
          identifier: 'security_policy_violations',
          status,
        },
      },
      provide: { glFeatures: { securityPolicyApprovalWarnMode: warnModeEnabled } },
      stubs: { ActionButtons },
    });
  }

  describe('action buttons', () => {
    it.each`
      status        | path                | exists   | rendersText
      ${'SUCCESS'}  | ${'/security-path'} | ${true}  | ${'renders'}
      ${'SUCCESS'}  | ${''}               | ${false} | ${'does not render'}
      ${'SUCCESS'}  | ${null}             | ${false} | ${'does not render'}
      ${'FAILED'}   | ${'/security-path'} | ${true}  | ${'renders'}
      ${'FAILED'}   | ${''}               | ${false} | ${'does not render'}
      ${'FAILED'}   | ${null}             | ${false} | ${'does not render'}
      ${'INACTIVE'} | ${'/security-path'} | ${false} | ${'does not render'}
      ${'INACTIVE'} | ${''}               | ${false} | ${'does not render'}
      ${'INACTIVE'} | ${null}             | ${false} | ${'does not render'}
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
      createComponent({ securityPoliciesPath: '/security-path' });

      expect(findViewPoliciesLink().exists()).toBe(true);
      expect(findViewPoliciesLink().attributes('href')).toBe('/security-path');
      expect(findViewPoliciesLink().text()).toBe('View policies');
    });
  });

  describe('bypass functionality', () => {
    it('shows bypass button when warn mode is enabled, has policies path, and has policies', async () => {
      createComponent({
        warnModeEnabled: true,
        securityPoliciesPath: '/security-path',
      });
      await waitForPromises();

      expect(findBypassButton().exists()).toBe(true);
    });

    it('does not show bypass button when warn mode is disabled', () => {
      createComponent({
        warnModeEnabled: false,
        securityPoliciesPath: '/security-path',
      });

      expect(findBypassButton().exists()).toBe(false);
    });

    it('does not show bypass button when no security policies path', () => {
      createComponent({
        warnModeEnabled: true,
        securityPoliciesPath: null,
      });

      expect(findBypassButton().exists()).toBe(false);
    });

    it('does not show bypass button when no policies', () => {
      createComponent({
        warnModeEnabled: true,
        securityPoliciesPath: '/security-path',
        policies: [],
      });

      expect(findBypassButton().exists()).toBe(false);
    });

    it('opens modal when bypass button is clicked', async () => {
      createComponent({
        warnModeEnabled: true,
        securityPoliciesPath: '/security-path',
      });
      await waitForPromises();

      expect(findModal().exists()).toBe(false);

      await findBypassButton().vm.$emit('click');

      expect(findModal().exists()).toBe(true);
    });

    it('closes modal when close event is emitted', async () => {
      createComponent({
        warnModeEnabled: true,
        securityPoliciesPath: '/security-path',
      });
      await waitForPromises();

      await findBypassButton().vm.$emit('click');
      expect(findModal().exists()).toBe(true);

      await findModal().vm.$emit('close');

      expect(findModal().exists()).toBe(false);
    });
  });
});
