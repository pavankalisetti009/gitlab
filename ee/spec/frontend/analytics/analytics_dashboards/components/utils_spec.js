import { isEmptyPanelData } from 'ee/analytics/analytics_dashboards/components/utils';

describe('isEmptyPanelData', () => {
  it.each`
    visualizationType | value  | expected
    ${'SingleStat'}   | ${[]}  | ${false}
    ${'SingleStat'}   | ${1}   | ${false}
    ${'LineChart'}    | ${[]}  | ${true}
    ${'LineChart'}    | ${[1]} | ${false}
  `(
    'returns $expected for visualization "$visualizationType" with value "$value"',
    ({ visualizationType, value, expected }) => {
      const result = isEmptyPanelData(visualizationType, value);
      expect(result).toBe(expected);
    },
  );
});
