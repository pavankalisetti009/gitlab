import { getVulnerabilityTotal } from 'ee/security_inventory/utils'; // Adjust the import according to your file structure

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
