import { highlightsFromReport } from 'ee/vue_merge_request_widget/widgets/security_reports/utils';

describe('MR Widget Security Reports Utils', () => {
  describe('highlightsFromReport', () => {
    it('should compute the highlights properly', () => {
      expect(
        highlightsFromReport({
          added: [
            { severity: 'high' },
            { severity: 'high' },
            { severity: 'critical' },
            { severity: 'critical' },
            { severity: 'critical' },
            { severity: 'medium' },
            { severity: 'low' },
            { severity: 'info' },
            { severity: 'unknown' },
          ],
        }),
      ).toEqual({
        critical: 3,
        high: 2,
        other: 4,
      });
    });

    it('should receive an object and modify it', () => {
      const highlights = {
        critical: 1,
        high: 0,
        other: 5,
      };

      expect(
        highlightsFromReport(
          { added: [{ severity: 'high' }, { severity: 'critical' }] },
          highlights,
        ),
      ).toEqual({
        critical: 2,
        high: 1,
        other: 5,
      });
    });
  });
});
