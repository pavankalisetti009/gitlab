import { s__ } from '~/locale';

/**
 * Formats vulnerability data by severity for chart visualization
 *
 * @param {Array} vulnerabilitiesOverTime - Array of vulnerability data nodes
 * @returns {Array} Formatted chart series data for severity grouping
 *
 * @note
 *
 * The `id`-property is used to construct the link to the vulnerability report page
 * and must match the filter value that is expected in the vulnerability report page
 * see `constructVulnerabilitiesReportWithFiltersPath` for more details
 */
const formatVulnerabilitiesBySeverity = (vulnerabilitiesOverTime) => {
  const chartSeriesDataBySeverity = {
    CRITICAL: { name: s__('severity|Critical'), id: 'CRITICAL', data: [] },
    HIGH: { name: s__('severity|High'), id: 'HIGH', data: [] },
    MEDIUM: { name: s__('severity|Medium'), id: 'MEDIUM', data: [] },
    LOW: { name: s__('severity|Low'), id: 'LOW', data: [] },
    INFO: { name: s__('severity|Info'), id: 'INFO', data: [] },
    UNKNOWN: { name: s__('severity|Unknown'), id: 'UNKNOWN', data: [] },
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
 *
 * @note
 *
 * The `id`-property is used to construct the link to the vulnerability report page
 * and must match the filter value that is expected in the vulnerability report page
 * see `constructVulnerabilitiesReportWithFiltersPath` for more details
 */
const formatVulnerabilitiesByReportType = (vulnerabilitiesOverTime) => {
  const chartSeriesDataByReportType = {
    SAST: { name: s__('reportType|SAST'), id: 'SAST', data: [] },
    DEPENDENCY_SCANNING: {
      name: s__('reportType|Dependency Scanning'),
      id: 'DEPENDENCY_SCANNING',
      data: [],
    },
    CONTAINER_SCANNING: {
      name: s__('reportType|Container Scanning'),
      id: 'CONTAINER_SCANNING',
      data: [],
    },
    DAST: { name: s__('reportType|DAST'), id: 'DAST', data: [] },
    SECRET_DETECTION: {
      name: s__('reportType|Secret Detection'),
      id: 'SECRET_DETECTION',
      data: [],
    },
    COVERAGE_FUZZING: {
      name: s__('reportType|Coverage Fuzzing'),
      id: 'COVERAGE_FUZZING',
      data: [],
    },
    API_FUZZING: { name: s__('reportType|API Fuzzing'), id: 'API_FUZZING', data: [] },
    CLUSTER_IMAGE_SCANNING: {
      name: s__('reportType|Cluster Image Scanning'),
      id: 'CLUSTER_IMAGE_SCANNING',
      data: [],
    },
    CONTAINER_SCANNING_FOR_REGISTRY: {
      name: s__('reportType|Container Scanning for Registry'),
      id: 'CONTAINER_SCANNING_FOR_REGISTRY',
      data: [],
    },
    GENERIC: { name: s__('reportType|Manually added'), id: 'GENERIC', data: [] },
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

/**
 * Constructs a link for the chart tooltip based on the series ID and group by
 *
 * @param {string} securityVulnerabilitiesPath - The path to the security vulnerabilities page
 * @param {string} seriesId - The ID of the series
 * @param {string} groupBy - The grouping to use for the chart. Can be 'severity' or 'reportType'.
 *
 * @note
 * This is a temporary solution until the link is provided by the GraphQL API
 * See https://gitlab.com/gitlab-org/gitlab/-/issues/559212 for more details
 */
export const constructVulnerabilitiesReportWithFiltersPath = ({
  securityVulnerabilitiesPath,
  seriesId,
  filterKey,
}) => {
  const SPECIAL_LINK_CASES = {
    CLUSTER_IMAGE_SCANNING: {
      // Cluster image scanning is a special case because it has a different tab in the vulnerability report page
      // eslint-disable-next-line @gitlab/require-i18n-strings
      linkSuffix: 'tab=OPERATIONAL',
    },
  };
  const linkSuffix = SPECIAL_LINK_CASES[seriesId]?.linkSuffix || `${filterKey}=${seriesId}`;

  return `${securityVulnerabilitiesPath}?activity=ALL&state=CONFIRMED,DETECTED&${linkSuffix}`;
};
