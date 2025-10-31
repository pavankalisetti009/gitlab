import { fillUsageValues } from 'ee/usage_quotas/usage_billing/utils';

describe('fillUsageValues', () => {
  describe('with complete usage data', () => {
    it('returns the provided values when all properties are present', () => {
      const usage = {
        creditsUsed: 100,
        totalCredits: 500,
        monthlyCommitmentCreditsUsed: 200,
        oneTimeCreditsUsed: 150,
        overageCreditsUsed: 75,
      };

      const result = fillUsageValues(usage);

      expect(result).toEqual({
        creditsUsed: 100,
        totalCredits: 500,
        monthlyCommitmentCreditsUsed: 200,
        oneTimeCreditsUsed: 150,
        overageCreditsUsed: 75,
      });
    });
  });

  describe('null value coalescing', () => {
    it('returns 0 for all properties when usage is null', () => {
      const result = fillUsageValues(null);

      expect(result).toEqual({
        creditsUsed: 0,
        totalCredits: 0,
        monthlyCommitmentCreditsUsed: 0,
        oneTimeCreditsUsed: 0,
        overageCreditsUsed: 0,
      });
    });

    it('returns 0 for all properties when usage is undefined', () => {
      const result = fillUsageValues(undefined);

      expect(result).toEqual({
        creditsUsed: 0,
        totalCredits: 0,
        monthlyCommitmentCreditsUsed: 0,
        oneTimeCreditsUsed: 0,
        overageCreditsUsed: 0,
      });
    });

    it('returns 0 for all properties when usage is an empty object', () => {
      const result = fillUsageValues({});

      expect(result).toEqual({
        creditsUsed: 0,
        totalCredits: 0,
        monthlyCommitmentCreditsUsed: 0,
        oneTimeCreditsUsed: 0,
        overageCreditsUsed: 0,
      });
    });

    it('handles mixed null and undefined values', () => {
      const usage = {
        creditsUsed: null,
        totalCredits: undefined,
        monthlyCommitmentCreditsUsed: 200,
        oneTimeCreditsUsed: null,
        overageCreditsUsed: undefined,
      };

      const result = fillUsageValues(usage);

      expect(result).toEqual({
        creditsUsed: 0,
        totalCredits: 0,
        monthlyCommitmentCreditsUsed: 200,
        oneTimeCreditsUsed: 0,
        overageCreditsUsed: 0,
      });
    });

    it('handles partial usage objects with missing properties', () => {
      const usage = {
        creditsUsed: 100,
        totalCredits: 500,
        // monthlyCommitmentCreditsUsed is missing
        // oneTimeCreditsUsed is missing
        overageCreditsUsed: 75,
      };

      const result = fillUsageValues(usage);

      expect(result).toEqual({
        creditsUsed: 100,
        totalCredits: 500,
        monthlyCommitmentCreditsUsed: 0,
        oneTimeCreditsUsed: 0,
        overageCreditsUsed: 75,
      });
    });

    it('handles falsy values that are not null or undefined', () => {
      const usage = {
        creditsUsed: false,
        totalCredits: '',
        monthlyCommitmentCreditsUsed: NaN,
        oneTimeCreditsUsed: 0,
        overageCreditsUsed: null,
      };

      const result = fillUsageValues(usage);

      expect(result).toEqual({
        creditsUsed: false,
        totalCredits: '',
        monthlyCommitmentCreditsUsed: NaN,
        oneTimeCreditsUsed: 0,
        overageCreditsUsed: 0,
      });
    });
  });
});
