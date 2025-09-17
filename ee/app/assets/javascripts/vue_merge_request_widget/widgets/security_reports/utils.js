import { CRITICAL, HIGH } from 'ee/vulnerabilities/constants';

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
