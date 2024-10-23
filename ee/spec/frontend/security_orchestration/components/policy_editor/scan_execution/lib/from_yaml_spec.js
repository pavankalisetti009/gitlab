import {
  createPolicyObject,
  fromYaml,
  hasInvalidScanners,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/lib/from_yaml';
import {
  actionId,
  unsupportedManifest,
  unsupportedManifestObject,
} from 'ee_jest/security_orchestration/mocks/mock_data';
import {
  mockDastScanExecutionManifest,
  mockDastScanExecutionObject,
  mockInvalidCadenceScanExecutionObject,
  mockInvalidCadenceScanExecutionManifest,
  mockBranchExceptionsScanExecutionObject,
  mockBranchExceptionsExecutionManifest,
  mockPolicyScopeExecutionManifest,
  mockPolicyScopeScanExecutionObject,
  mockTemplateScanExecutionManifest,
  mockTemplateScanExecutionObject,
  mockInvalidTemplateScanExecutionManifest,
  mockInvalidTemplateScanExecutionObject,
  mockScanSettingsScanExecutionManifest,
  mockScanSettingsScanExecutionObject,
} from 'ee_jest/security_orchestration/mocks/mock_scan_execution_policy_data';

jest.mock('lodash/uniqueId', () => jest.fn((prefix) => `${prefix}0`));

describe('fromYaml', () => {
  it.each`
    title                                                              | manifest                                    | output                                                                                                        | features
    ${'policy object for an unsupported attribute'}                    | ${unsupportedManifest}                      | ${{ parsingError: { hasParsingError: false }, policy: unsupportedManifestObject }}                            | ${{}}
    ${'policy object for a branch exceptions'}                         | ${mockBranchExceptionsExecutionManifest}    | ${{ parsingError: { hasParsingError: false }, policy: mockBranchExceptionsScanExecutionObject }}              | ${{}}
    ${'policy object for a project scope'}                             | ${mockPolicyScopeExecutionManifest}         | ${{ parsingError: { hasParsingError: false }, policy: mockPolicyScopeScanExecutionObject }}                   | ${{}}
    ${'policy object for a valid template value'}                      | ${mockTemplateScanExecutionManifest}        | ${{ parsingError: { hasParsingError: false }, policy: mockTemplateScanExecutionObject }}                      | ${{}}
    ${'policy object with an error for an invalid template value'}     | ${mockInvalidTemplateScanExecutionManifest} | ${{ parsingError: { hasParsingError: true, actions: true }, policy: mockInvalidTemplateScanExecutionObject }} | ${{}}
    ${'policy object with an error for an invalid cadence cron value'} | ${mockInvalidCadenceScanExecutionManifest}  | ${{ parsingError: { hasParsingError: true, rules: true }, policy: mockInvalidCadenceScanExecutionObject }}    | ${{}}
    ${'policy object for a manifest with settings'}                    | ${mockScanSettingsScanExecutionManifest}    | ${{ parsingError: { hasParsingError: false }, policy: mockScanSettingsScanExecutionObject }}                  | ${{}}
  `('returns the $title', ({ manifest, output, features }) => {
    window.gon = { features };
    expect(fromYaml({ manifest, validateRuleMode: true })).toStrictEqual(output);
  });

  describe('without validation', () => {
    it.each`
      title                                       | manifest                         | policy                         | features
      ${'a manifest with supported attributes'}   | ${mockDastScanExecutionManifest} | ${mockDastScanExecutionObject} | ${{}}
      ${'a manifest with unsupported attributes'} | ${unsupportedManifest}           | ${unsupportedManifestObject}   | ${{}}
    `('returns the policy object for $title', ({ manifest, policy, features }) => {
      window.gon = { features };
      expect(fromYaml({ manifest })).toStrictEqual({
        parsingError: { hasParsingError: false },
        policy,
      });
    });
  });
});

describe('createPolicyObject', () => {
  it.each`
    title                                                                          | input                                         | output
    ${'returns the policy object and no errors for a supported manifest'}          | ${[mockDastScanExecutionManifest]}            | ${{ parsingError: { hasParsingError: false }, policy: mockDastScanExecutionObject }}
    ${'returns the error policy object and the error for an unsupported manifest'} | ${[mockInvalidTemplateScanExecutionManifest]} | ${{ parsingError: { hasParsingError: true, actions: true }, policy: mockInvalidTemplateScanExecutionObject }}
  `('$title', ({ input, output }) => {
    expect(createPolicyObject(...input)).toStrictEqual(output);
  });
});

describe('hasInvalidScanners', () => {
  it.each`
    title                                                | input                                                                                 | output
    ${'return false when all scanners are supported'}    | ${[{ scan: 'sast', id: actionId }, { scan: 'dast', id: actionId }]}                   | ${false}
    ${'return true when not all scanners are supported'} | ${[{ scan: 'sast', id: actionId }, { scan: 'cluster_image_scanning', id: actionId }]} | ${true}
    ${'return true when no valid scanners'}              | ${[{ scan2: 'sast' }, { scan3: 'cluster_image_scanning' }]}                           | ${true}
  `('$title', ({ input, output }) => {
    expect(hasInvalidScanners(input)).toBe(output);
  });
});
