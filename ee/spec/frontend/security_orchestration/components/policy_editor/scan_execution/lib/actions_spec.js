import {
  buildScannerAction,
  addDefaultVariablesToManifest,
  addDefaultVariablesToPolicy,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/lib/actions';
import {
  REPORT_TYPE_DAST,
  REPORT_TYPE_SAST,
  REPORT_TYPE_SAST_IAC,
  REPORT_TYPE_SECRET_DETECTION,
  REPORT_TYPE_API_FUZZING,
} from '~/vue_shared/security_reports/constants';
import {
  DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE,
  DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE_WITH_DEFAULT_VARIABLES,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/lib';

const actionId = 'action_0';
jest.mock('lodash/uniqueId', () => jest.fn().mockReturnValue(actionId));

describe('buildScannerAction', () => {
  describe('DAST', () => {
    it('returns a DAST scanner action with empty profiles', () => {
      expect(buildScannerAction({ scanner: REPORT_TYPE_DAST })).toEqual({
        scan: REPORT_TYPE_DAST,
        site_profile: '',
        scanner_profile: '',
        id: actionId,
      });
    });

    it('returns a DAST scanner action with filled profiles', () => {
      const siteProfile = 'test_site_profile';
      const scannerProfile = 'test_scanner_profile';

      expect(
        buildScannerAction({ scanner: REPORT_TYPE_DAST, siteProfile, scannerProfile }),
      ).toEqual({
        scan: REPORT_TYPE_DAST,
        site_profile: siteProfile,
        scanner_profile: scannerProfile,
        id: actionId,
      });
    });
  });

  describe('non-DAST', () => {
    it('returns a non-DAST scanner action', () => {
      const scanner = 'sast';
      expect(buildScannerAction({ scanner })).toEqual({
        scan: scanner,
        id: actionId,
      });
    });
  });

  describe('optimized scanning', () => {
    it('adds template property when isOptimized is true', () => {
      expect(buildScannerAction({ scanner: 'sast', isOptimized: true })).toEqual({
        scan: 'sast',
        id: 'action_0',
        template: 'latest',
      });
    });
  });
});

describe('addDefaultVariablesToPolicy', () => {
  const buildPayload = (scan, variables = undefined) => {
    return variables ? { actions: [{ scan, variables }] } : { actions: [{ scan }] };
  };

  it.each`
    policy                                                                                                   | expected
    ${buildPayload(REPORT_TYPE_SAST)}                                                                        | ${buildPayload(REPORT_TYPE_SAST, { SECURE_ENABLE_LOCAL_CONFIGURATION: 'false' })}
    ${buildPayload(REPORT_TYPE_SAST_IAC)}                                                                    | ${buildPayload(REPORT_TYPE_SAST_IAC, { SECURE_ENABLE_LOCAL_CONFIGURATION: 'false' })}
    ${buildPayload(REPORT_TYPE_SECRET_DETECTION)}                                                            | ${buildPayload(REPORT_TYPE_SECRET_DETECTION, { SECURE_ENABLE_LOCAL_CONFIGURATION: 'false' })}
    ${buildPayload(REPORT_TYPE_DAST)}                                                                        | ${buildPayload(REPORT_TYPE_DAST)}
    ${buildPayload(REPORT_TYPE_DAST, { SECURE_ENABLE_LOCAL_CONFIGURATION: 'false' })}                        | ${buildPayload(REPORT_TYPE_DAST)}
    ${buildPayload(REPORT_TYPE_API_FUZZING)}                                                                 | ${buildPayload(REPORT_TYPE_API_FUZZING)}
    ${buildPayload(REPORT_TYPE_API_FUZZING, { SECURE_ENABLE_LOCAL_CONFIGURATION: 'false' })}                 | ${buildPayload(REPORT_TYPE_API_FUZZING)}
    ${buildPayload(REPORT_TYPE_API_FUZZING, { SECURE_ENABLE_LOCAL_CONFIGURATION: 'false', OTHER: 'value' })} | ${buildPayload(REPORT_TYPE_API_FUZZING, { OTHER: 'value' })}
    ${buildPayload(REPORT_TYPE_SAST, { SECURE_ENABLE_LOCAL_CONFIGURATION: 'true' })}                         | ${buildPayload(REPORT_TYPE_SAST, { SECURE_ENABLE_LOCAL_CONFIGURATION: 'true' })}
    ${buildPayload(REPORT_TYPE_SECRET_DETECTION, { SECURE_ENABLE_LOCAL_CONFIGURATION: undefined })}          | ${buildPayload(REPORT_TYPE_SECRET_DETECTION, { SECURE_ENABLE_LOCAL_CONFIGURATION: undefined })}
  `('adds default variable to a policy with specific scanners', ({ policy, expected }) => {
    expect(addDefaultVariablesToPolicy({ policy })).toEqual(expected);
  });
});

describe('addDefaultVariablesToManifest', () => {
  it('adds default variable to a policy manifest with specific scanners', () => {
    expect(
      addDefaultVariablesToManifest({ manifest: DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE }),
    ).toBe(DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE_WITH_DEFAULT_VARIABLES);
  });
});
