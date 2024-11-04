import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import Settings from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_settings.vue';
import {
  mockApprovalSettingsScanResultObject,
  mockApprovalSettingsPermittedInvalidScanResultObject,
  mockDisabledApprovalSettingsScanResultObject,
} from '../../../mocks/mock_scan_result_policy_data';

describe('Settings', () => {
  let wrapper;

  const findHeader = () => wrapper.find('h5');
  const findSettings = () => wrapper.findAll('li');
  const findGroupBranchExceptions = () => wrapper.findByTestId('group-branch-exceptions');

  const factory = (propsData) => {
    wrapper = shallowMountExtended(Settings, {
      propsData,
      stubs: { GlSprintf },
    });
  };

  it('displays settings', () => {
    factory({ settings: mockApprovalSettingsScanResultObject.approval_settings });
    expect(findHeader().exists()).toBe(true);
    expect(findSettings()).toHaveLength(2);
    expect(findSettings().at(0).text()).toBe('Prevent branch modification');
    expect(findSettings().at(1).text()).toBe('Prevent pushing and force pushing');
  });

  it('does not show for a policy without "approval_settings" property', () => {
    factory({ settings: {} });
    expect(findHeader().exists()).toBe(false);
    expect(findSettings().exists()).toBe(false);
  });

  it('does not show for a policy with only invalid settings', () => {
    factory({ settings: mockApprovalSettingsPermittedInvalidScanResultObject.approval_settings });
    expect(findHeader().exists()).toBe(false);
    expect(findSettings().exists()).toBe(false);
  });

  it('does not show for policies with only disabled settings', () => {
    factory({ settings: mockDisabledApprovalSettingsScanResultObject.approval_settings });
    expect(findHeader().exists()).toBe(false);
    expect(findSettings().exists()).toBe(false);
  });

  describe('block group branch modification', () => {
    it('renders when setting is "true"', () => {
      factory({ settings: { block_group_branch_modification: true } });
      expect(findHeader().exists()).toBe(true);
      expect(findSettings()).toHaveLength(1);
      expect(findSettings().at(0).text()).toBe('Prevent group branch modification');
      expect(findGroupBranchExceptions().exists()).toBe(false);
    });

    it('renders when setting has exceptions', () => {
      factory({
        settings: {
          block_group_branch_modification: { enabled: true, exceptions: ['top-level-group'] },
        },
      });
      expect(findHeader().exists()).toBe(true);
      expect(findGroupBranchExceptions().exists()).toBe(true);
      expect(findSettings().at(0).text()).toMatchInterpolatedText(
        'Prevent group branch modification exceptions: top-level-group',
      );
    });
  });
});
