import { GlPopover, GlIcon } from '@gitlab/ui';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PolicyOverrideText from 'ee/approvals/components/approval_settings/policy_override_text.vue';
import PolicyOverrideWarningIcon from 'ee/approvals/components/approval_settings/policy_override_warning_icon.vue';
import {
  BLOCK_BRANCH_MODIFICATION,
  PREVENT_APPROVAL_BY_AUTHOR,
  REQUIRE_PASSWORD_TO_APPROVE,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import { mockProjectApprovalSettingsScanResultPolicy } from 'ee_jest/security_orchestration/mocks/mock_scan_result_policy_data';
import securityOrchestrationModule from 'ee/approvals/stores/modules/security_orchestration';
import createStore from 'ee/approvals/stores';
import { gqClient } from 'ee/security_orchestration/utils';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(Vuex);

const policiesQueryResponse = {
  data: {
    namespace: {
      securityPolicies: {
        nodes: [mockProjectApprovalSettingsScanResultPolicy],
      },
    },
  },
};
const emptyPoliciesQueryResponse = { data: { project: { securityPolicies: { nodes: [] } } } };

describe('PolicyOverrideWarningIcon', () => {
  let wrapper;
  let store;
  let actions;
  const fullPath = 'full/path';

  const scanResultPoliciesWithoutApprovalSettings = [{ name: 'policy 1', enabled: true }];
  const scanResultPoliciesWithEmptyApprovalSettings = [
    { name: 'policy 1', enabled: true, approval_settings: {} },
  ];
  const scanResultPoliciesDisabled = [
    { name: 'policy 1', enabled: false, approval_settings: { [PREVENT_APPROVAL_BY_AUTHOR]: true } },
  ];
  const scanResultPoliciesWithoutMergeRequestApprovalSettings = [
    { name: 'policy 1', enabled: true, approval_settings: { [BLOCK_BRANCH_MODIFICATION]: true } },
  ];
  const scanResultPoliciesWithApprovalSettings = [
    {
      name: 'policy 1',
      enabled: true,
      enforcement_type: 'enforce',
      approval_settings: { [PREVENT_APPROVAL_BY_AUTHOR]: true },
      editPath: 'link 1',
    },
    {
      name: 'policy 2',
      enabled: true,
      enforcement_type: 'enforce',
      approval_settings: { [REQUIRE_PASSWORD_TO_APPROVE]: true },
      editPath: 'link 2',
    },
    {
      name: 'policy 3',
      enabled: true,
      enforcement_type: 'warn',
      approval_settings: { [REQUIRE_PASSWORD_TO_APPROVE]: true },
      editPath: 'link 2',
    },
  ];

  const setupStore = (scanResultPolicies = []) => {
    const module = securityOrchestrationModule();

    actions = module.actions;
    store = createStore({
      securityOrchestrationModule: module,
    });
    store.state.securityOrchestrationModule.scanResultPolicies = scanResultPolicies;
  };

  const createComponent = ({ provideData = {} } = {}) => {
    wrapper = shallowMountExtended(PolicyOverrideWarningIcon, {
      store,
      stubs: { GlPopover },
      provide: {
        fullPath,
        ...provideData,
      },
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findAllPolicyOverrideTexts = () => wrapper.findAllComponents(PolicyOverrideText);

  afterEach(() => {
    store = null;
  });

  describe('fetchScanResultPolicies', () => {
    beforeEach(() => {
      setupStore();
    });

    it('fetches scanResultPolicies from API', () => {
      jest.spyOn(actions, 'fetchScanResultPolicies').mockImplementation();
      setupStore();
      createComponent();

      expect(actions.fetchScanResultPolicies).toHaveBeenCalledWith(expect.any(Object), {
        fullPath,
        isGroup: false,
      });
    });

    it('fetches group scanResultPolicies from API when isGroup is injected and is true', () => {
      jest.spyOn(actions, 'fetchScanResultPolicies').mockImplementation();
      setupStore();
      createComponent({ provideData: { isGroup: true } });

      expect(actions.fetchScanResultPolicies).toHaveBeenCalledWith(expect.any(Object), {
        fullPath,
        isGroup: true,
      });
    });
  });

  describe('initial rendering based on queried data', () => {
    it('does not render the icon without policies', async () => {
      jest.spyOn(gqClient, 'query').mockResolvedValue(emptyPoliciesQueryResponse);
      setupStore();
      createComponent();
      await waitForPromises();

      expect(findIcon().exists()).toBe(false);
    });

    it('renders the icon with policies', async () => {
      jest.spyOn(gqClient, 'query').mockResolvedValue(policiesQueryResponse);
      setupStore();
      createComponent();
      await waitForPromises();

      expect(findIcon().props('name')).toBe('warning');
    });
  });

  it.each`
    scanResultPolicies                                       | expectedExists
    ${[]}                                                    | ${false}
    ${scanResultPoliciesDisabled}                            | ${false}
    ${scanResultPoliciesWithoutApprovalSettings}             | ${false}
    ${scanResultPoliciesWithoutMergeRequestApprovalSettings} | ${false}
    ${scanResultPoliciesWithEmptyApprovalSettings}           | ${false}
    ${scanResultPoliciesWithApprovalSettings}                | ${true}
  `('renders based on scan result policies', ({ scanResultPolicies, expectedExists }) => {
    setupStore(scanResultPolicies);
    createComponent();

    expect(findIcon().exists()).toBe(expectedExists);
  });

  describe('enforced policies', () => {
    beforeEach(() => {
      setupStore([scanResultPoliciesWithApprovalSettings[0]]);
      createComponent();
    });

    it('renders warning icon', () => {
      expect(findIcon().props('name')).toBe('warning');
      expect(findPopover().exists()).toBe(true);
    });

    it('renders enforced policy text', () => {
      expect(findAllPolicyOverrideTexts()).toHaveLength(1);
      const enforcedText = findAllPolicyOverrideTexts().at(0);
      expect(enforcedText.props('policies')).toHaveLength(1);
      expect(enforcedText.props('policies')[0].name).toBe('policy 1');
      expect(enforcedText.props('isWarn')).toBe(false);
    });
  });

  describe('warn policies', () => {
    it('renders warning icon and popover for warn mode policy', () => {
      setupStore([scanResultPoliciesWithApprovalSettings[2]]);
      createComponent();
      expect(findAllPolicyOverrideTexts()).toHaveLength(1);
      const warnText = findAllPolicyOverrideTexts().at(0);
      expect(warnText.props('policies')).toHaveLength(1);
      expect(warnText.props('policies')[0].name).toBe('policy 3');
      expect(warnText.props('isWarn')).toBe(true);
    });
  });

  describe('mixed enforced policies', () => {
    beforeEach(() => {
      setupStore(scanResultPoliciesWithApprovalSettings);
      createComponent();
    });

    it('renders enforced policy text', () => {
      expect(findAllPolicyOverrideTexts()).toHaveLength(2);
      const enforcedText = findAllPolicyOverrideTexts().at(0);
      expect(enforcedText.props('policies')).toHaveLength(2);
      expect(enforcedText.props('policies')[0].name).toBe('policy 1');
      expect(enforcedText.props('policies')[1].name).toBe('policy 2');
      expect(enforcedText.props('isWarn')).toBe(false);
    });

    it('renders warning icon and popover for warn mode policy', () => {
      const warnText = findAllPolicyOverrideTexts().at(1);
      expect(warnText.props('policies')).toHaveLength(1);
      expect(warnText.props('policies')[0].name).toBe('policy 3');
      expect(warnText.props('isWarn')).toBe(true);
    });
  });
});
