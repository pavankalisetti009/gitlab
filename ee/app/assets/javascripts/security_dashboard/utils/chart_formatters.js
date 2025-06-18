import { s__ } from '~/locale';

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
 * @returns {Array} Formatted chart series data
 *   Expected data structure: [
 *     { name: 'Critical', data: [[timestamp1, count1], [timestamp2, count2], ...] },
 *     { name: 'High', data: [[timestamp1, count1], [timestamp2, count2], ...] },
 *     ...
 *   ]
 */
export const formatVulnerabilitiesOverTimeData = (vulnerabilitiesOverTime) => {
  if (!Array.isArray(vulnerabilitiesOverTime) || vulnerabilitiesOverTime.length === 0) {
    return [];
  }

  const chartSeriesData = {
    critical: { name: s__('severity|Critical'), data: [] },
    high: { name: s__('severity|High'), data: [] },
    medium: { name: s__('severity|Medium'), data: [] },
    low: { name: s__('severity|Low'), data: [] },
    info: { name: s__('severity|Info'), data: [] },
    unknown: { name: s__('severity|Unknown'), data: [] },
  };

  vulnerabilitiesOverTime.forEach((node) => {
    const { date, bySeverity } = node;

    bySeverity.forEach(({ severity, count }) => {
      if (chartSeriesData[severity]) {
        chartSeriesData[severity].data.push([date, count]);
      }
    });
  });

  return Object.values(chartSeriesData);
};
