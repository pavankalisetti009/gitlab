import { s__ } from '~/locale';

/**
 * Formats vulnerability data by severity for chart visualization
 *
 * @param {Array} vulnerabilitiesOverTime - Array of vulnerability data nodes
 * @returns {Array} Formatted chart series data for severity grouping
 */
const formatVulnerabilitiesBySeverity = (vulnerabilitiesOverTime) => {
  const chartSeriesDataBySeverity = {
    CRITICAL: { name: s__('severity|Critical'), data: [] },
    HIGH: { name: s__('severity|High'), data: [] },
    MEDIUM: { name: s__('severity|Medium'), data: [] },
    LOW: { name: s__('severity|Low'), data: [] },
    INFO: { name: s__('severity|Info'), data: [] },
    UNKNOWN: { name: s__('severity|Unknown'), data: [] },
  };

  vulnerabilitiesOverTime.forEach((node) => {
    const { date, bySeverity = [] } = node;
    bySeverity.forEach(({ severity, count }) => {
      if (chartSeriesDataBySeverity[severity]) {
        chartSeriesDataBySeverity[severity].data.push([date, count]);
      }
    });
  });

  return Object.values(chartSeriesDataBySeverity).filter((item) => item.data.length > 0);
};

/**
 * Formats vulnerability data by report type for chart visualization
 *
 * @param {Array} vulnerabilitiesOverTime - Array of vulnerability data nodes
 * @returns {Array} Formatted chart series data for report type grouping
 */
const formatVulnerabilitiesByReportType = (vulnerabilitiesOverTime) => {
  const chartSeriesDataByReportType = {
    SAST: { name: s__('reportType|SAST'), data: [] },
    DEPENDENCY_SCANNING: { name: s__('reportType|Dependency Scanning'), data: [] },
    CONTAINER_SCANNING: { name: s__('reportType|Container Scanning'), data: [] },
    DAST: { name: s__('reportType|DAST'), data: [] },
    SECRET_DETECTION: { name: s__('reportType|Secret Detection'), data: [] },
    COVERAGE_FUZZING: { name: s__('reportType|Coverage Fuzzing'), data: [] },
    API_FUZZING: { name: s__('reportType|API Fuzzing'), data: [] },
    CLUSTER_IMAGE_SCANNING: { name: s__('reportType|Cluster Image Scanning'), data: [] },
    CONTAINER_SCANNING_FOR_REGISTRY: {
      name: s__('reportType|Container Scanning for Registry'),
      data: [],
    },
    GENERIC: { name: s__('reportType|Generic'), data: [] },
  };

  vulnerabilitiesOverTime.forEach((node) => {
    const { date, byReportType = [] } = node;
    byReportType.forEach(({ reportType, count }) => {
      if (chartSeriesDataByReportType[reportType]) {
        chartSeriesDataByReportType[reportType].data.push([date, count]);
      }
    });
  });

  return Object.values(chartSeriesDataByReportType).filter((item) => item.data.length > 0);
};

/**
 * Formats vulnerability data over time for chart visualization
 *
 * @param {Array} vulnerabilitiesOverTime - Array of vulnerability data nodes
 *   Each node should have the structure:
 *   {
 *     date: string,
 *     bySeverity: [
 *       { severity: string, count: number },
 *       ...
 *     ]
 *   }
 *
 * @param {string} groupBy - The grouping to use for the chart. Can be 'severity' or 'reportType'.
 *   Defaults to 'severity'.
 *
 * @returns {Array} Formatted chart series data
 *   Expected data structure: [
 *     { name: 'Critical', data: [[timestamp1, count1], [timestamp2, count2], ...] },
 *     { name: 'High', data: [[timestamp1, count1], [timestamp2, count2], ...] },
 *     ...
 *   ]
 */
export const formatVulnerabilitiesOverTimeData = (
  vulnerabilitiesOverTime,
  groupBy = 'severity',
) => {
  if (!Array.isArray(vulnerabilitiesOverTime) || vulnerabilitiesOverTime.length === 0) {
    return [];
  }

  if (groupBy === 'severity') {
    return formatVulnerabilitiesBySeverity(vulnerabilitiesOverTime);
  }
  return formatVulnerabilitiesByReportType(vulnerabilitiesOverTime);
};
