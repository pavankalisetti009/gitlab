import { CRITICAL, HIGH } from 'ee/vulnerabilities/constants';
import { SECURITY_SCAN_TO_REPORT_TYPE } from '~/vue_merge_request_widget/constants';

export function highlightsFromReport(report, highlights = { [HIGH]: 0, [CRITICAL]: 0, other: 0 }) {
  // The data we receive from the API is something like:
  // [
  //  { scanner: "SAST", added: [{ id: 15, severity: 'critical' }] },
  //  { scanner: "DAST", added: [{ id: 15, severity: 'high' }] },
  //  ...
  // ]
  return [...(report.full?.added || []), ...(report.partial?.added || [])].reduce((acc, vuln) => {
    if (vuln.severity === HIGH) {
      acc[HIGH] += 1;
    } else if (vuln.severity === CRITICAL) {
      acc[CRITICAL] += 1;
    } else {
      acc.other += 1;
    }
    return acc;
  }, highlights);
}

const getEnabledScanTypes = (scanData, scanMode) => {
  if (!scanData) return [];

  return Object.entries(scanData)
    .filter(
      ([scanType, isEnabled]) => isEnabled === true && scanType in SECURITY_SCAN_TO_REPORT_TYPE,
    )
    .map(([scanType]) => ({
      reportType: SECURITY_SCAN_TO_REPORT_TYPE[scanType],
      scanMode,
    }));
};

/**
 * Transforms GraphQL enabled security scans into report type configuration.
 * @param {Object} scans
 * @param {Object} scans.enabledSecurityScans
 * @returns {Array<{reportType: string, scanMode: string}>}
 * @example
 * const scans = {
 *   enabledSecurityScans: { sast: true, dast: false },
 *   enabledPartialSecurityScans: { sast: true, dast: false }
 * };
 * transformToEnabledScans(scans)
 * // Returns:
 * [
 *   { reportType: 'SAST', scanMode: 'FULL' },
 *   { reportType: 'SAST', scanMode: 'PARTIAL' },
 * ]
 */
export function transformToEnabledScans(scans) {
  return [
    ...getEnabledScanTypes(scans.enabledSecurityScans, 'FULL'),
    ...getEnabledScanTypes(scans.enabledPartialSecurityScans, 'PARTIAL'),
  ];
}
