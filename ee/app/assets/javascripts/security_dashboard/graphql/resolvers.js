/* eslint-disable @gitlab/require-i18n-strings */
const BUCKETS = [
  '<7 days',
  '7-14 days',
  '15-30 days',
  '31-60 days',
  '61-90 days',
  '90-180 days',
  '180+ days',
];
/* eslint-enable @gitlab/require-i18n-strings */

const SEVERITIES = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'INFO', 'UNKNOWN'];
const REPORT_TYPE = ['SAST', 'DEPENDENCY_SCANNING'];

const randomCount = (max = 50) => Math.floor(Math.random() * max);

const generateBuckets = () =>
  BUCKETS.map((name) => ({
    __typename: 'VulnerabilitiesByAgeBucket',
    name,
    bySeverity: SEVERITIES.map((severity) => ({
      __typename: 'VulnerabilitySeverityCount',
      severity,
      count: randomCount(),
    })),
    byReportType: REPORT_TYPE.map((reportType) => ({
      __typename: 'VulnerabilityReportTypeCount',
      reportType,
      count: randomCount(),
    })),
  }));

const resolvers = {
  SecurityMetrics: {
    vulnerabilitiesByAge: async (_parent, args) => {
      const buckets = generateBuckets();

      // Filter by severity if provided
      const filteredBuckets = args.severity?.length
        ? buckets.map((bucket) => ({
            ...bucket,
            bySeverity: bucket.bySeverity.filter((s) => args.severity.includes(s.severity)),
          }))
        : buckets;

      await new Promise((resolve) => {
        setTimeout(resolve, 1000);
      });

      return filteredBuckets;
    },
  },
};

export default resolvers;
