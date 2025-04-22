import { getVulnerabilityTotal, filterSecurityScanners } from 'ee/security_inventory/utils'; // Adjust the import according to your file structure

describe('getVulnerabilityTotal', () => {
  it('should return 0 when no vulnerabilities are provided', () => {
    const result = getVulnerabilityTotal();
    expect(result).toBe(0);
  });

  it('should return the correct total when given specific vulnerability counts', () => {
    const vulnerabilityCounts = {
      critical: 3,
      high: 5,
      medium: 2,
      low: 1,
      info: 0,
      unknown: 4,
    };
    const result = getVulnerabilityTotal(vulnerabilityCounts);
    expect(result).toBe(15);
  });

  it('should handle missing fields by defaulting to 0', () => {
    const vulnerabilityCounts = {
      critical: 3,
      high: 2,
      medium: 1,
    };
    const result = getVulnerabilityTotal(vulnerabilityCounts);
    expect(result).toBe(6);
  });

  it('should return 0 when passed an empty object', () => {
    const result = getVulnerabilityTotal({});
    expect(result).toBe(0);
  });
});

describe('filterSecurityScanners', () => {
  it('returns empty arrays when given no input', () => {
    expect(filterSecurityScanners()).toEqual({
      scannerTypes: [],
      enabled: [],
      pipelineRun: [],
    });
  });

  it('filters enabled scanners correctly', () => {
    const scanners = ['SAST', 'ADVANCED_SAST'];
    const securityScanners = {
      enabled: ['SAST', 'CONTAINER_SCANNING'],
      pipelineRun: ['SAST', 'CONTAINER_SCANNING'],
    };
    expect(filterSecurityScanners(scanners, securityScanners)).toEqual({
      scannerTypes: ['SAST', 'ADVANCED_SAST'],
      enabled: ['SAST'],
      pipelineRun: ['SAST'],
    });
  });

  it('filters pipelineRun scanners correctly', () => {
    const scanners = ['CONTAINER_SCANNING'];
    const securityScanners = {
      enabled: ['SAST'],
      pipelineRun: ['CONTAINER_SCANNING', 'SAST'],
    };
    expect(filterSecurityScanners(scanners, securityScanners)).toEqual({
      scannerTypes: ['CONTAINER_SCANNING'],
      enabled: [],
      pipelineRun: ['CONTAINER_SCANNING'],
    });
  });

  it('returns empty enabled and pipelineRun arrays if no matches', () => {
    const scanners = ['DAST'];
    const securityScanners = {
      enabled: ['SAST'],
      pipelineRun: ['SAST'],
    };
    expect(filterSecurityScanners(scanners, securityScanners)).toEqual({
      scannerTypes: ['DAST'],
      enabled: [],
      pipelineRun: [],
    });
  });

  it('handles missing securityScanners object missing', () => {
    const scanners = ['SAST', 'DAST'];
    expect(filterSecurityScanners(scanners)).toEqual({
      scannerTypes: ['SAST', 'DAST'],
      enabled: [],
      pipelineRun: [],
    });
  });
});
