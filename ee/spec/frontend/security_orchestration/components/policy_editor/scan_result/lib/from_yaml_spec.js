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
  mockProjectFallbackClosedScanResultManifest,
  mockProjectFallbackClosedScanResultObject,
  multipleApproverActionsScanResultManifest,
  multipleApproverActionsScanResultObject,
  zeroActionsScanResultManifest,
  zeroActionsScanResultObject,
  mockFallbackInvalidScanResultManifest,
  mockProjectPolicyTuningScanResultManifest,
  mockProjectPolicyTuningScanResultObject,
  allowDenyScanResultLicenseManifest,
  allowDenyScanResultLicenseObject,
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
      ${'with policy_tuning'}                                             | ${mockProjectPolicyTuningScanResultManifest}              | ${mockProjectPolicyTuningScanResultObject}
      ${'with `approval_settings` containing permitted invalid settings'} | ${mockApprovalSettingsPermittedInvalidScanResultManifest} | ${mockApprovalSettingsPermittedInvalidScanResultObject}
      ${'with multiple actions'}                                          | ${multipleApproverActionsScanResultManifest}              | ${multipleApproverActionsScanResultObject}
    `('returns the policy object for a manifest $title', ({ manifest, output }) => {
      expect(fromYaml({ manifest, validateRuleMode: true })).toStrictEqual(output);
    });

    it('returns the policy object for a manifest license scaner with exceptions', () => {
      window.gon = { features: { excludeLicensePackages: true } };

      expect(
        fromYaml({ manifest: allowDenyScanResultLicenseManifest, validateRuleMode: true }),
      ).toStrictEqual(allowDenyScanResultLicenseObject);
    });
  });

  describe('error', () => {
    it.each`
      title                                  | manifest
      ${'unsupported fallback behavior'}     | ${mockFallbackInvalidScanResultManifest}
      ${'an unsupported attribute'}          | ${unsupportedManifest}
      ${'colliding self excluded keys'}      | ${collidingKeysScanResultManifest}
      ${'allow deny license exception keys'} | ${allowDenyScanResultLicenseManifest}
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
