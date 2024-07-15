import {
  generateDateRanges,
  generateTableColumns,
  generateSkeletonTableData,
  calculateChange,
  generateTableRows,
  calculateCodeSuggestionsUsageRate,
  getRestrictedTableMetrics,
  generateTableAlerts,
} from 'ee/analytics/dashboards/ai_impact/utils';
import {
  SUPPORTED_DORA_METRICS,
  SUPPORTED_FLOW_METRICS,
  SUPPORTED_VULNERABILITY_METRICS,
} from 'ee/analytics/dashboards/ai_impact/constants';
import { mockTimePeriods } from './mock_data';

describe('AI impact Dashboard utils', () => {
  describe('generateDateRanges', () => {
    it.each`
      date            | description
      ${'07-01-2021'} | ${'on the first of the month'}
      ${'03-31-2021'} | ${'on the last of the month'}
      ${'03-31-2020'} | ${'in a leap year'}
    `('returns the expected date ranges $description', ({ date }) => {
      expect(generateDateRanges(new Date(date))).toMatchSnapshot();
    });
  });

  describe('generateTableColumns', () => {
    it.each`
      date            | description
      ${'07-01-2021'} | ${'on the first of the month'}
      ${'03-31-2021'} | ${'on the last of the month'}
      ${'03-31-2020'} | ${'in a leap year'}
    `('returns the expected table fields $description', ({ date }) => {
      expect(generateTableColumns(new Date(date))).toMatchSnapshot();
    });
  });

  describe('generateSkeletonTableData', () => {
    it('returns the skeleton based on the table fields', () => {
      expect(generateSkeletonTableData()).toMatchSnapshot();
    });
  });

  describe('calculateChange', () => {
    it.each`
      current      | previous     | value    | tooltip
      ${0}         | ${10}        | ${-1}    | ${undefined}
      ${0}         | ${-10}       | ${1}     | ${undefined}
      ${100}       | ${200}       | ${-0.5}  | ${undefined}
      ${0}         | ${0}         | ${0}     | ${'No change'}
      ${'0.0'}     | ${'0.0'}     | ${0}     | ${'No change'}
      ${10}        | ${10}        | ${0}     | ${'No change'}
      ${10}        | ${0}         | ${'n/a'} | ${"Value can't be calculated due to division by zero."}
      ${undefined} | ${100}       | ${'n/a'} | ${"Value can't be calculated due to insufficient data."}
      ${null}      | ${100}       | ${'n/a'} | ${"Value can't be calculated due to insufficient data."}
      ${'-'}       | ${100}       | ${'n/a'} | ${"Value can't be calculated due to insufficient data."}
      ${100}       | ${undefined} | ${'n/a'} | ${"Value can't be calculated due to insufficient data."}
      ${100}       | ${null}      | ${'n/a'} | ${"Value can't be calculated due to insufficient data."}
      ${100}       | ${'-'}       | ${'n/a'} | ${"Value can't be calculated due to insufficient data."}
      ${'-'}       | ${'-'}       | ${'n/a'} | ${'No data available'}
    `(
      '($current, $previous) returns { value: $value, tooltip: `$tooltip` }',
      ({ current, previous, value, tooltip }) => {
        expect(calculateChange(current, previous)).toEqual({ value, tooltip });
      },
    );
  });

  describe('generateTableRows', () => {
    it('returns the data formatted as a table row', () => {
      expect(generateTableRows(mockTimePeriods)).toMatchSnapshot();
    });
  });

  describe('calculateCodeSuggestionsUsageRate', () => {
    it('returns null when counts are undefined', () => {
      expect(calculateCodeSuggestionsUsageRate()).toBeNull();
    });

    it('returns null when there is no code suggestions usage data', () => {
      expect(
        calculateCodeSuggestionsUsageRate({
          codeSuggestionsContributorsCount: 0,
          codeContributorsCount: 0,
        }),
      ).toBeNull();
    });

    it('returns the code suggestions usage rate as expected', () => {
      expect(
        calculateCodeSuggestionsUsageRate({
          codeSuggestionsContributorsCount: 3,
          codeContributorsCount: 4,
        }),
      ).toEqual(75);
    });
  });

  describe('getRestrictedTableMetrics', () => {
    it('restricts DORA metrics when the permission is disabled', () => {
      const permissions = { readCycleAnalytics: true, readSecurityResource: true };
      expect(getRestrictedTableMetrics(permissions)).toEqual(SUPPORTED_DORA_METRICS);
    });

    it('restricts flow metrics when the permission is disabled', () => {
      const permissions = { readDora4Analytics: true, readSecurityResource: true };
      expect(getRestrictedTableMetrics(permissions)).toEqual(SUPPORTED_FLOW_METRICS);
    });

    it('restricts vulnerability metrics when the permission is disabled', () => {
      const permissions = { readDora4Analytics: true, readCycleAnalytics: true };
      expect(getRestrictedTableMetrics(permissions)).toEqual(SUPPORTED_VULNERABILITY_METRICS);
    });
  });

  describe('generateTableAlerts', () => {
    it('returns the list of alerts that have associated metrics', () => {
      const errors = 'errors';
      const warnings = 'warnings';
      expect(
        generateTableAlerts([
          [errors, SUPPORTED_FLOW_METRICS],
          [warnings, SUPPORTED_DORA_METRICS],
          ['no error', []],
        ]),
      ).toEqual([
        `${errors}: Cycle time, Lead time`,
        `${warnings}: Deployment frequency, Change failure rate`,
      ]);
    });
  });
});
