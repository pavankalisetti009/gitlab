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
      (!('status' in item) || typeof item.status === 'string') &&
      (!('buildId' in item) || typeof item.buildId === 'string') &&
      (!('lastCall' in item) || typeof item.lastCall === 'string') &&
      (!('updatedAt' in item) || typeof item.updatedAt === 'string'),
  );
};

/**
 * Validator function for item prop
 * @param {Object} value - Object item of project tool coverage
 * @returns {Boolean} True if all items have valid structure, false otherwise
 */
export const itemValidator = (value) => {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    return false;
  }
  if ('analyzerStatuses' in value) {
    if (
      !Array.isArray(value.analyzerStatuses) ||
      !securityScannerValidator(value.analyzerStatuses)
    ) {
      return false;
    }
  }
  if ('path' in value && typeof value.path !== 'string') {
    return false;
  }
  return !('webUrl' in value && typeof value.webUrl !== 'string');
};
