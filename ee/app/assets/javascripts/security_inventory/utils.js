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
 * Validator function for securityScanner prop
 * @param {Array<Object>} value - Array of security scanner objects
 * @returns {Boolean} True if all items have valid structure, false otherwise
 */
export const securityScannerValidator = (value) => {
  return value.every(
    (item) =>
      typeof item === 'object' &&
      'analyzerType' in item &&
      typeof item.analyzerType === 'string' &&
      (!('status' in item) || typeof item.status === 'string'),
  );
};
