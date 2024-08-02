import { shallowMount } from '@vue/test-utils';
import Settings from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_settings.vue';
import {
  mockApprovalSettingsScanResultObject,
  mockApprovalSettingsPermittedInvalidScanResultObject,
} from '../../../mocks/mock_scan_result_policy_data';

describe('Settings', () => {
  let wrapper;

  const findHeader = () => wrapper.find('h5');
  const findSettings = () => wrapper.findAll('li');

  const factory = (propsData) => {
    wrapper = shallowMount(Settings, {
      propsData,
    });
  };

  it('displays settings', () => {
    factory({ settings: mockApprovalSettingsScanResultObject.approval_settings });
    expect(findHeader().exists()).toBe(true);
    expect(findSettings()).toHaveLength(2);
    expect(findSettings().at(0).text()).toBe('Prevent project branch modification');
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
});
