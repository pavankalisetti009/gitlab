import {
  formatVulnerabilitiesOverTimeData,
  constructVulnerabilitiesReportWithFiltersPath,
} from 'ee/security_dashboard/utils/chart_utils';

describe('Security Dashboard - Chart Utils', () => {
  const severities = ['Critical', 'High', 'Medium', 'Low', 'Info', 'Unknown'];
  const reportTypes = [
    'SAST',
    'Dependency Scanning',
    'Container Scanning',
    'DAST',
    'Secret Detection',
    'Coverage Fuzzing',
    'API Fuzzing',
    'Cluster Image Scanning',
    'Container Scanning for Registry',
    'Manually added',
  ];

  const mockVulnerabilitiesData = [
    {
      date: '2024-01-01',
      bySeverity: [
        { severity: 'CRITICAL', count: 5 },
        { severity: 'HIGH', count: 10 },
        { severity: 'MEDIUM', count: 15 },
      ],
      byReportType: [
        { reportType: 'SAST', count: 8 },
        { reportType: 'DEPENDENCY_SCANNING', count: 12 },
        { reportType: 'CONTAINER_SCANNING', count: 10 },
        { reportType: 'SECRET_DETECTION', count: 2 },
        { reportType: 'COVERAGE_FUZZING', count: 4 },
        { reportType: 'CLUSTER_IMAGE_SCANNING', count: 6 },
        { reportType: 'CONTAINER_SCANNING_FOR_REGISTRY', count: 8 },
        { reportType: 'GENERIC', count: 10 },
      ],
    },
    {
      date: '2024-01-02',
      bySeverity: [
        { severity: 'CRITICAL', count: 3 },
        { severity: 'HIGH', count: 8 },
        { severity: 'LOW', count: 12 },
        { severity: 'INFO', count: 2 },
        { severity: 'UNKNOWN', count: 4 },
      ],
      byReportType: [
        { reportType: 'DAST', count: 5 },
        { reportType: 'API_FUZZING', count: 3 },
        { reportType: 'SAST', count: 6 },
      ],
    },
  ];

  const getSeriesByName = (name, result) => result.find((series) => series.name === name);
  const getSeriesNames = (result) => result.map((series) => series.name);

  describe('formatVulnerabilitiesOverTimeData', () => {
    describe('when groupBy is "severity" (default)', () => {
      it.each(severities)('includes the correct id for "%s"', (severity) => {
        const result = formatVulnerabilitiesOverTimeData(mockVulnerabilitiesData);

        expect(getSeriesByName(severity, result).id).toEqual(severity.toUpperCase());
      });

      it('includes correct data points for all severities', () => {
        const result = formatVulnerabilitiesOverTimeData(mockVulnerabilitiesData);

        expect(getSeriesNames(result)).toEqual(severities);
        expect(getSeriesByName('Critical', result).data).toEqual([
          ['2024-01-01', 5],
          ['2024-01-02', 3],
        ]);
        expect(getSeriesByName('High', result).data).toEqual([
          ['2024-01-01', 10],
          ['2024-01-02', 8],
        ]);
      });

      it('handles edge cases correctly', () => {
        const edgeCaseData = [
          {
            date: '2024-01-01',
            bySeverity: [
              { severity: 'CRITICAL', count: 0 },
              { severity: 'nonexistent', count: 3 },
            ],
          },
          {
            date: '2024-01-02',
            bySeverity: [],
          },
        ];

        const result = formatVulnerabilitiesOverTimeData(edgeCaseData);

        expect(getSeriesByName('Critical', result).data).toEqual([['2024-01-01', 0]]);
        expect(getSeriesByName('nonexistent', result)).toBeUndefined();
      });
    });

    describe('when groupBy is "reportType"', () => {
      it('includes correct data points for all report types', () => {
        const result = formatVulnerabilitiesOverTimeData(mockVulnerabilitiesData, 'reportType');

        expect(getSeriesNames(result)).toEqual(reportTypes);
        expect(getSeriesByName('SAST', result).data).toEqual([
          ['2024-01-01', 8],
          ['2024-01-02', 6],
        ]);
        expect(getSeriesByName('DAST', result).data).toEqual([['2024-01-02', 5]]);
      });

      it('handles edge cases correctly', () => {
        const edgeCaseData = [
          {
            date: '2024-01-01',
            byReportType: [
              { reportType: 'SAST', count: 0 },
              { reportType: 'nonexistent', count: 3 },
            ],
          },
          {
            date: '2024-01-02',
            byReportType: [],
          },
        ];

        const result = formatVulnerabilitiesOverTimeData(edgeCaseData, 'reportType');

        expect(getSeriesByName('SAST', result).data).toEqual([['2024-01-01', 0]]);
        expect(getSeriesByName('nonexistent', result)).toBeUndefined();
      });
    });

    describe('groupBy parameter behavior', () => {
      it('defaults to "severity" when no groupBy is provided', () => {
        const result = formatVulnerabilitiesOverTimeData(mockVulnerabilitiesData);
        expect(getSeriesNames(result)).toEqual(severities);
      });

      it('uses "reportType" when groupBy is set to "reportType"', () => {
        const result = formatVulnerabilitiesOverTimeData(mockVulnerabilitiesData, 'reportType');
        expect(getSeriesNames(result)).toEqual(reportTypes);
      });
    });

    describe('input validation', () => {
      it.each([[], null, undefined])('returns an empty array when the input is "%s"', (input) => {
        expect(formatVulnerabilitiesOverTimeData(input)).toEqual([]);
        expect(formatVulnerabilitiesOverTimeData(input, 'reportType')).toEqual([]);
      });
    });
  });

  describe('constructVulnerabilitiesReportWithFiltersPath', () => {
    const securityVulnerabilitiesPath = '/security/vulnerabilities';

    it('constructs path with filter key and series ID', () => {
      const result = constructVulnerabilitiesReportWithFiltersPath({
        seriesId: 'SAST',
        filterKey: 'report_type',
        securityVulnerabilitiesPath,
      });

      expect(result).toBe(
        `${securityVulnerabilitiesPath}?activity=ALL&state=CONFIRMED,DETECTED&report_type=SAST`,
      );
    });

    describe('special cases', () => {
      it('constructs path with operational tab suffix', () => {
        const result = constructVulnerabilitiesReportWithFiltersPath({
          seriesId: 'CLUSTER_IMAGE_SCANNING',
          securityVulnerabilitiesPath,
        });

        expect(result).toBe(
          `${securityVulnerabilitiesPath}?activity=ALL&state=CONFIRMED,DETECTED&tab=OPERATIONAL`,
        );
      });
    });
  });
});
