import { convertToTitleCase } from '~/lib/utils/text_utility';
import DetailsDrawer from 'ee/security_orchestration/components/policy_drawer/scan_result/details_drawer.vue';
import ToggleList from 'ee/security_orchestration/components/policy_drawer/toggle_list.vue';
import PolicyDrawerLayout from 'ee/security_orchestration/components/policy_drawer/drawer_layout.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import Approvals from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_approvals.vue';
import Settings from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_settings.vue';
import EdgeCaseSettings from 'ee/security_orchestration/components/policy_drawer/scan_result/edge_case_settings.vue';
import DenyAllowViewList from 'ee/security_orchestration/components/policy_drawer/scan_result/deny_allow_view_list.vue';
import {
  disabledSendBotMessageActionScanResultManifest,
  enabledSendBotMessageActionScanResultManifest,
  mockProjectScanResultPolicy,
  mockProjectWithAllApproverTypesScanResultPolicy,
  mockProjectApprovalSettingsScanResultPolicy,
  mockProjectFallbackClosedScanResultManifest,
  mockNoFallbackScanResultManifest,
  zeroActionsScanResultManifest,
  mockProjectPolicyTuningScanResultManifest,
  allowDenyScanResultLicenseNonEmptyManifest,
  mockWarnActionScanResultManifest,
} from 'ee_jest/security_orchestration/mocks/mock_scan_result_policy_data';

describe('DetailsDrawer component', () => {
  let wrapper;

  const findFallbackDetails = () => wrapper.findByTestId('fallback-details');
  const findSummary = () => wrapper.findByTestId('policy-summary');
  const findPolicyApprovals = () => wrapper.findComponent(Approvals);
  const findPolicyDrawerLayout = () => wrapper.findComponent(PolicyDrawerLayout);
  const findToggleList = () => wrapper.findComponent(ToggleList);
  const findSettings = () => wrapper.findComponent(Settings);
  const findBotMessage = () => wrapper.findByTestId('policy-bot-message');
  const findApprovalSubheader = () => wrapper.findByTestId('approvals-subheader');
  const findEdgeCaseSettings = () => wrapper.findComponent(EdgeCaseSettings);
  const findDenyAllowViewList = () => wrapper.findComponent(DenyAllowViewList);

  const factory = ({ props, provide = {} } = {}) => {
    wrapper = shallowMountExtended(DetailsDrawer, {
      propsData: {
        policy: mockProjectScanResultPolicy,
        ...props,
      },
      provide: { namespaceType: NAMESPACE_TYPES.PROJECT, ...provide },
      stubs: {
        PolicyDrawerLayout,
      },
    });
  };

  describe('policy drawer layout props', () => {
    it('passes the policy to the PolicyDrawerLayout component', () => {
      factory();
      expect(findPolicyDrawerLayout().props('policy')).toBe(mockProjectScanResultPolicy);
    });

    it('passes the description to the PolicyDrawerLayout component', () => {
      factory();
      expect(findPolicyDrawerLayout().props('description')).toBe(
        'This policy enforces critical vulnerability CS approvals',
      );
    });

    it('renders layout if yaml is invalid', () => {
      factory({ props: { policy: {} } });

      expect(findPolicyDrawerLayout().exists()).toBe(true);
      expect(findPolicyDrawerLayout().props('description')).toBe('');
      expect(findDenyAllowViewList().exists()).toBe(false);
    });
  });

  describe('summary', () => {
    it('renders the policy summary', () => {
      factory();
      expect(findSummary().exists()).toBe(true);
    });

    describe('settings', () => {
      it('passes the settings to the "Settings" component if settings are present', () => {
        factory({ props: { policy: mockProjectApprovalSettingsScanResultPolicy } });
        expect(findSettings().props('settings')).toEqual(
          mockProjectApprovalSettingsScanResultPolicy.approval_settings,
        );
      });

      it('passes the empty object to the "Settings" component if no settings are present', () => {
        factory();
        expect(findSettings().props('settings')).toEqual({});
      });
    });

    describe('approvals', () => {
      it('renders the "Approvals" component correctly', () => {
        factory({ props: { policy: mockProjectWithAllApproverTypesScanResultPolicy } });
        expect(findPolicyApprovals().exists()).toBe(true);
        expect(findPolicyApprovals().props('isLastItem')).toBe(false);
        expect(findPolicyApprovals().props('isWarnMode')).toBe(false);
        expect(findApprovalSubheader().exists()).toBe(true);
        expect(findPolicyApprovals().props('approvers')).toStrictEqual([
          ...mockProjectWithAllApproverTypesScanResultPolicy.actionApprovers[0].allGroups,
          ...mockProjectWithAllApproverTypesScanResultPolicy.actionApprovers[0].roles.map((r) =>
            convertToTitleCase(r.toLowerCase()),
          ),
          ...mockProjectWithAllApproverTypesScanResultPolicy.actionApprovers[0].users,
        ]);
      });

      it('should not render branch exceptions list without exceptions', () => {
        factory({ props: { policy: mockProjectWithAllApproverTypesScanResultPolicy } });
        expect(findToggleList().exists()).toBe(false);
      });

      it('renders in warn mode', () => {
        factory({
          props: {
            policy: {
              ...mockProjectWithAllApproverTypesScanResultPolicy,
              yaml: mockWarnActionScanResultManifest,
            },
          },
        });
        expect(findPolicyApprovals().exists()).toBe(true);
        expect(findPolicyApprovals().props('isLastItem')).toBe(false);
        expect(findPolicyApprovals().props('isWarnMode')).toBe(true);
        expect(findBotMessage().exists()).toBe(false);
      });
    });

    describe('send bot message', () => {
      it('hides the text when it is disabled', () => {
        factory({
          props: {
            policy: {
              ...mockProjectWithAllApproverTypesScanResultPolicy,
              yaml: disabledSendBotMessageActionScanResultManifest,
            },
          },
        });
        expect(findBotMessage().exists()).toBe(false);
        expect(findApprovalSubheader().exists()).toBe(false);
      });

      it('shows the message when the action is not included', () => {
        factory({ props: { policy: mockProjectScanResultPolicy } });
        expect(findBotMessage().text()).toBe('Send a bot message when the conditions match.');
      });

      it('shows the message when the action is enabled', () => {
        factory({
          props: {
            policy: {
              ...mockProjectWithAllApproverTypesScanResultPolicy,
              yaml: enabledSendBotMessageActionScanResultManifest,
            },
          },
        });
        expect(findBotMessage().text()).toBe('Send a bot message when the conditions match.');
      });

      it('shows the message when there are zero actions is enabled', () => {
        factory({
          props: {
            policy: {
              ...mockProjectWithAllApproverTypesScanResultPolicy,
              yaml: zeroActionsScanResultManifest,
            },
          },
        });
        expect(findBotMessage().exists()).toBe(true);
        expect(findApprovalSubheader().exists()).toBe(false);
      });
    });
  });

  describe('fallback behavior', () => {
    it('does not render the fallback behavior section if the policy does not have the fallback behavior property', () => {
      factory({
        props: {
          policy: { ...mockProjectScanResultPolicy, yaml: mockNoFallbackScanResultManifest },
        },
      });
      expect(findFallbackDetails().isVisible()).toBe(false);
      expect(findFallbackDetails().text()).toBe('');
    });

    it('renders the open fallback behavior', () => {
      factory();
      expect(findFallbackDetails().isVisible()).toBe(true);
      expect(findFallbackDetails().text()).toBe(
        'Fail open: Allow the merge request to proceed, even if not all criteria are met',
      );
    });

    it('renders the closed fallback behavior', () => {
      factory({
        props: {
          policy: {
            ...mockProjectScanResultPolicy,
            yaml: mockProjectFallbackClosedScanResultManifest,
          },
        },
      });
      expect(findFallbackDetails().isVisible()).toBe(true);
      expect(findFallbackDetails().text()).toBe(
        'Fail closed: Block the merge request until all criteria are met',
      );
    });
  });

  describe('edge case settings', () => {
    it('does not render the edge case settings', () => {
      factory();
      expect(findEdgeCaseSettings().exists()).toBe(false);
    });

    it('does render the edge case settings', () => {
      factory({
        props: {
          policy: {
            ...mockProjectScanResultPolicy,
            yaml: mockProjectPolicyTuningScanResultManifest,
          },
        },
      });
      expect(findEdgeCaseSettings().exists()).toBe(true);
    });
  });

  describe('deny allow license exceptions table', () => {
    it('renders allow deny list when license packages exist', () => {
      window.gon = { features: { excludeLicensePackages: true } };
      factory({
        props: {
          policy: {
            ...mockProjectScanResultPolicy,
            yaml: allowDenyScanResultLicenseNonEmptyManifest,
          },
        },
        provide: {
          glFeatures: {
            excludeLicensePackages: true,
          },
        },
      });

      expect(findDenyAllowViewList().exists()).toBe(true);
      expect(findDenyAllowViewList().props('items')).toEqual([
        { license: { value: 'MIT', text: 'MIT' }, exceptions: [] },
        {
          license: { value: 'NPM', text: 'NPM' },
          exceptions: ['pkg:npm40angular/animation', 'pkg:npm40angular/animation@12.3.1'],
        },
      ]);
    });
  });
});
