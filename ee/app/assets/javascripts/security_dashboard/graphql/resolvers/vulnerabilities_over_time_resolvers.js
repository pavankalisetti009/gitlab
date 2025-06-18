export default {
  Group: {
    securityMetrics: () => {
      return {
        __typename: 'SecurityMetrics',
      };
    },
  },
  SecurityMetrics: {
    vulnerabilitiesOverTime: async () => {
      // This simulates data from 2025-04-17 to 2025-04-26
      const dates = [
        '2025-04-17',
        '2025-04-18',
        '2025-04-19',
        '2025-04-20',
        '2025-04-21',
        '2025-04-22',
        '2025-04-23',
        '2025-04-24',
        '2025-04-25',
        '2025-04-26',
      ];

      const severityData = {
        critical: [5, 5, 7, 7, 6, 8, 10, 10, 12, 11],
        high: [25, 27, 30, 30, 28, 31, 35, 35, 38, 36],
        medium: [45, 47, 50, 52, 48, 51, 55, 55, 58, 56],
        low: [65, 68, 72, 72, 69, 73, 78, 78, 82, 79],
        info: [12, 15, 15, 18, 18, 16, 19, 19, 22, 22],
        unknown: [8, 8, 10, 10, 9, 9, 12, 12, 11, 11],
      };

      // simulate data fetching delay
      await new Promise((resolve) => {
        setTimeout(resolve, 1000);
      });

      const result = {
        __typename: 'VulnerabilitiesOverTime',
        nodes: dates.map((date, index) => ({
          __typename: 'VulnerabilityDateData',
          date,
          bySeverity: [
            {
              __typename: 'VulnerabilitySeverityCount',
              severity: 'critical',
              count: severityData.critical[index],
            },
            {
              __typename: 'VulnerabilitySeverityCount',
              severity: 'high',
              count: severityData.high[index],
            },
            {
              __typename: 'VulnerabilitySeverityCount',
              severity: 'medium',
              count: severityData.medium[index],
            },
            {
              __typename: 'VulnerabilitySeverityCount',
              severity: 'low',
              count: severityData.low[index],
            },
            {
              __typename: 'VulnerabilitySeverityCount',
              severity: 'info',
              count: severityData.info[index],
            },
            {
              __typename: 'VulnerabilitySeverityCount',
              severity: 'unknown',
              count: severityData.unknown[index],
            },
          ],
        })),
      };
      return result;
    },
  },
};
