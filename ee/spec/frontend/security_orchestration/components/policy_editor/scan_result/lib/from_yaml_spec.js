import {
  createPolicyObject,
  fromYaml,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import {
  collidingKeysScanResultManifest,
  mockDefaultBranchesScanResultManifest,
  mockDefaultBranchesScanResultObject,
  mockProjectApprovalSettingsScanResultManifest,
  mockApprovalSettingsScanResultObject,
  mockGroupApprovalSettingsScanResultManifest,
  mockGroupApprovalSettingsScanResultObject,
  mockApprovalSettingsPermittedInvalidScanResultManifest,
  mockApprovalSettingsPermittedInvalidScanResultObject,
  mockPolicyScopeScanResultManifest,
  mockPolicyScopeScanResultObject,
  mockProjectFallbackClosedScanResultManifest,
  mockProjectFallbackClosedScanResultObject,
  tooManyActionsScanResultManifest,
  duplicateActionsScanResultManifest,
  zeroActionsScanResultManifest,
  zeroActionsScanResultObject,
  mockFallbackInvalidScanResultManifest,
} from 'ee_jest/security_orchestration/mocks/mock_scan_result_policy_data';
import {
  unsupportedManifest,
  unsupportedManifestObject,
} from 'ee_jest/security_orchestration/mocks/mock_data';

afterEach(() => {
  window.gon = {};
});

jest.mock('lodash/uniqueId', () => jest.fn((prefix) => `${prefix}0`));

describe('fromYaml', () => {
  describe('success', () => {
    it.each`
      title                                                               | manifest                                                  | output
      ${'without approval_settings'}                                      | ${mockDefaultBranchesScanResultManifest}                  | ${mockDefaultBranchesScanResultObject}
      ${'with approval_settings'}                                         | ${mockProjectApprovalSettingsScanResultManifest}          | ${mockApprovalSettingsScanResultObject}
      ${'with the `BLOCK_GROUP_BRANCH_MODIFICATION` approval_setting'}    | ${mockGroupApprovalSettingsScanResultManifest}            | ${mockGroupApprovalSettingsScanResultObject}
      ${'without actions'}                                                | ${zeroActionsScanResultManifest}                          | ${zeroActionsScanResultObject}
      ${'with fail: closed'}                                              | ${mockProjectFallbackClosedScanResultManifest}            | ${mockProjectFallbackClosedScanResultObject}
      ${'with `approval_settings` containing permitted invalid settings'} | ${mockApprovalSettingsPermittedInvalidScanResultManifest} | ${mockApprovalSettingsPermittedInvalidScanResultObject}
      ${'with `policy_scope` by default'}                                 | ${mockPolicyScopeScanResultManifest}                      | ${mockPolicyScopeScanResultObject}
    `('returns the policy object for a manifest $title', ({ manifest, output }) => {
      expect(fromYaml({ manifest, validateRuleMode: true })).toStrictEqual(output);
    });
  });

  describe('error', () => {
    it.each`
      title                              | manifest
      ${'unsupported fallback behavior'} | ${mockFallbackInvalidScanResultManifest}
      ${'more than two actions'}         | ${tooManyActionsScanResultManifest}
      ${'duplicate action types'}        | ${duplicateActionsScanResultManifest}
      ${'an unsupported attribute'}      | ${unsupportedManifest}
      ${'colliding self excluded keys'}  | ${collidingKeysScanResultManifest}
    `('returns the error object for a policy with $title', ({ manifest }) => {
      expect(fromYaml({ manifest, validateRuleMode: true })).toStrictEqual({ error: true });
    });
  });

  describe('skipped validation', () => {
    it('return the policy object for a manifest with an unsupported attribute', () => {
      expect(fromYaml({ manifest: unsupportedManifest })).toStrictEqual(unsupportedManifestObject);
    });
  });
});

describe('createPolicyObject', () => {
  it.each`
    title                                                                          | input                                    | output
    ${'returns the policy object and no errors for a supported manifest'}          | ${mockDefaultBranchesScanResultManifest} | ${{ policy: mockDefaultBranchesScanResultObject, hasParsingError: false }}
    ${'returns the error policy object and the error for an unsupported manifest'} | ${unsupportedManifest}                   | ${{ policy: { error: true }, hasParsingError: true }}
    ${'returns the error policy object and the error for an colliding keys'}       | ${collidingKeysScanResultManifest}       | ${{ policy: { error: true }, hasParsingError: true }}
  `('$title', ({ input, output }) => {
    expect(createPolicyObject(input)).toStrictEqual(output);
  });
});
