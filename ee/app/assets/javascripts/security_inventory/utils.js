/**
 * Calculate the total number of vulnerabilities across different severities
 * @param {Object} vulnerabilitySeveritiesCount - An object containing the count of vulnerabilities for each severity level
 * @returns {number} The total number of vulnerabilities
 */
export const getVulnerabilityTotal = (vulnerabilitySeveritiesCount = {}) => {
  const {
    critical = 0,
    high = 0,
    medium = 0,
    low = 0,
    info = 0,
    unknown = 0,
  } = vulnerabilitySeveritiesCount || {};

  return critical + high + medium + low + info + unknown;
};

export const isSubGroup = (item) => {
  // eslint-disable-next-line no-underscore-dangle
  return item.__typename === 'Group';
};

/**
 * Filter security scanners based on scanner type
 * @param {Array} scanners - Array of scanner types to filter
 * @param {Object} securityScanners - Object containing enabled and pipelineRun scanners, and the relevant scanner
 * @returns {Object} Filtered security scanners object
 */
export const filterSecurityScanners = (
  scanners = [],
  securityScanners = { enabled: [], pipelineRun: [] },
) => {
  return {
    scannerTypes: scanners,
    enabled: securityScanners.enabled?.filter((scanner) => scanners.includes(scanner)) || [],
    pipelineRun:
      securityScanners.pipelineRun?.filter((scanner) => scanners.includes(scanner)) || [],
  };
};
