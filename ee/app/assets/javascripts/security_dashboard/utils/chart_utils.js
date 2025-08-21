import GroupVulnerabilitiesForSeverityPanel from 'ee/security_dashboard/components/shared/group_vulnerabilities_for_severity_panel.vue';
import { markRaw } from '~/lib/utils/vue3compat/mark_raw';
import { s__ } from '~/locale';
import { SEVERITY_LEVELS_KEYS } from '../constants';

export const SEVERITY_LEVELS = {
  CRITICAL: s__('severity|Critical'),
  HIGH: s__('severity|High'),
  MEDIUM: s__('severity|Medium'),
  LOW: s__('severity|Low'),
  INFO: s__('severity|Info'),
  UNKNOWN: s__('severity|Unknown'),
};

// Constants for vulnerability report URL parameters
export const ACTIVITY_FILTERS = {
  ALL: 'ALL',
};

export const STATE_FILTERS = {
  CONFIRMED: 'CONFIRMED',
  DETECTED: 'DETECTED',
};

export const TAB_FILTERS = {
  OPERATIONAL: 'OPERATIONAL',
};

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
    CRITICAL: { name: SEVERITY_LEVELS.CRITICAL, id: 'CRITICAL', data: [] },
    HIGH: { name: SEVERITY_LEVELS.HIGH, id: 'HIGH', data: [] },
    MEDIUM: { name: SEVERITY_LEVELS.MEDIUM, id: 'MEDIUM', data: [] },
    LOW: { name: SEVERITY_LEVELS.LOW, id: 'LOW', data: [] },
    INFO: { name: SEVERITY_LEVELS.INFO, id: 'INFO', data: [] },
    UNKNOWN: { name: SEVERITY_LEVELS.UNKNOWN, id: 'UNKNOWN', data: [] },
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
 * @param {string} filterKey - The primary filter key (usually the groupedBy value)
 * @param {Object} additionalFilters - Additional filters to include in the URL
 *
 * @note
 * This is a temporary solution until the link is provided by the GraphQL API
 * See https://gitlab.com/gitlab-org/gitlab/-/issues/559212 for more details
 */
export const constructVulnerabilitiesReportWithFiltersPath = ({
  securityVulnerabilitiesPath,
  seriesId,
  filterKey,
  additionalFilters = {},
}) => {
  const SPECIAL_LINK_CASES = {
    CLUSTER_IMAGE_SCANNING: {
      // Cluster image scanning is a special case because it has a different tab in the vulnerability report page
      tab: TAB_FILTERS.OPERATIONAL,
    },
  };

  const params = new URLSearchParams();

  // Add default parameters
  params.set('activity', ACTIVITY_FILTERS.ALL);
  params.set('state', `${STATE_FILTERS.CONFIRMED},${STATE_FILTERS.DETECTED}`);

  const specialCase = SPECIAL_LINK_CASES[seriesId];
  if (specialCase) {
    Object.entries(specialCase).forEach(([key, value]) => {
      params.set(key, value);
    });
  } else {
    params.set(filterKey, seriesId);
  }

  Object.entries(additionalFilters).forEach(([key, value]) => {
    if (key !== filterKey && value && value.length > 0) {
      // A filter can have multiple values (e.g. severity=HIGH,MEDIUM) so we need to join them with commas
      const filterValue = Array.isArray(value) ? value.join(',') : value;
      params.set(key, filterValue);
    }
  });

  return `${securityVulnerabilitiesPath}?${params.toString()}`;
};

const DEFAULT_PANEL_WIDTH = 2;
const DEFAULT_PANEL_HEIGHT = 1;

/**
 * Generates configuration objects for vulnerability count per severity panels.
 *
 * Creates a horizontally-aligned row of panels, one for each severity level,
 * with each panel positioned sequentially from left to right.
 *
 * @param {Object} filters - GraphQL query filters
 * @returns {Array<Object>} Array of panel configuration objects
 */
export const generateVulnerabilitiesForSeverityPanels = (filters) => {
  return SEVERITY_LEVELS_KEYS.map((severity, index) => ({
    id: severity,
    component: markRaw(GroupVulnerabilitiesForSeverityPanel),
    componentProps: {
      severity,
      filters,
    },
    gridAttributes: {
      width: DEFAULT_PANEL_WIDTH,
      height: DEFAULT_PANEL_HEIGHT,
      yPos: 0,
      xPos: DEFAULT_PANEL_WIDTH * index,
    },
  }));
};
