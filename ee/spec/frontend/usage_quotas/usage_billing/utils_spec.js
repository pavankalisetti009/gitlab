import {
  fillUsageValues,
  formatNumber,
  ensureAbsoluteCustomerPortalUrl,
} from 'ee/usage_quotas/usage_billing/utils';

describe('fillUsageValues', () => {
  describe('with complete usage data', () => {
    it('returns the provided values when all properties are present', () => {
      const usage = {
        creditsUsed: 100,
        totalCredits: 500,
        monthlyCommitmentCreditsUsed: 200,
        monthlyWaiverCreditsUsed: 150,
        overageCreditsUsed: 75,
      };

      const result = fillUsageValues(usage);

      expect(result).toEqual({
        creditsUsed: 100,
        totalCredits: 500,
        monthlyCommitmentCreditsUsed: 200,
        monthlyWaiverCreditsUsed: 150,
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
        monthlyWaiverCreditsUsed: 0,
        overageCreditsUsed: 0,
      });
    });

    it('returns 0 for all properties when usage is undefined', () => {
      const result = fillUsageValues(undefined);

      expect(result).toEqual({
        creditsUsed: 0,
        totalCredits: 0,
        monthlyCommitmentCreditsUsed: 0,
        monthlyWaiverCreditsUsed: 0,
        overageCreditsUsed: 0,
      });
    });

    it('returns 0 for all properties when usage is an empty object', () => {
      const result = fillUsageValues({});

      expect(result).toEqual({
        creditsUsed: 0,
        totalCredits: 0,
        monthlyCommitmentCreditsUsed: 0,
        monthlyWaiverCreditsUsed: 0,
        overageCreditsUsed: 0,
      });
    });

    it('handles mixed null and undefined values', () => {
      const usage = {
        creditsUsed: null,
        totalCredits: undefined,
        monthlyCommitmentCreditsUsed: 200,
        monthlyWaiverCreditsUsed: null,
        overageCreditsUsed: undefined,
      };

      const result = fillUsageValues(usage);

      expect(result).toEqual({
        creditsUsed: 0,
        totalCredits: 0,
        monthlyCommitmentCreditsUsed: 200,
        monthlyWaiverCreditsUsed: 0,
        overageCreditsUsed: 0,
      });
    });

    it('handles partial usage objects with missing properties', () => {
      const usage = {
        creditsUsed: 100,
        totalCredits: 500,
        // monthlyCommitmentCreditsUsed is missing
        // monthlyWaiverCreditsUsed is missing
        overageCreditsUsed: 75,
      };

      const result = fillUsageValues(usage);

      expect(result).toEqual({
        creditsUsed: 100,
        totalCredits: 500,
        monthlyCommitmentCreditsUsed: 0,
        monthlyWaiverCreditsUsed: 0,
        overageCreditsUsed: 75,
      });
    });

    it('handles falsy values that are not null or undefined', () => {
      const usage = {
        creditsUsed: false,
        totalCredits: '',
        monthlyCommitmentCreditsUsed: NaN,
        monthlyWaiverCreditsUsed: 0,
        overageCreditsUsed: null,
      };

      const result = fillUsageValues(usage);

      expect(result).toEqual({
        creditsUsed: false,
        totalCredits: '',
        monthlyCommitmentCreditsUsed: NaN,
        monthlyWaiverCreditsUsed: 0,
        overageCreditsUsed: 0,
      });
    });
  });
});

describe('formatNumber', () => {
  describe.each`
    number       | expected
    ${0}         | ${'0'}
    ${0.5}       | ${'0.5'}
    ${0.9001}    | ${'0.9'}
    ${0.9999}    | ${'1.0'}
    ${5.35}      | ${'5.4'}
    ${17.35}     | ${'17.4'}
    ${42}        | ${'42'}
    ${999.2}     | ${'999.2'}
    ${1000}      | ${'1k'}
    ${1500}      | ${'1.5k'}
    ${NaN}       | ${'NaN'}
    ${null}      | ${'null'}
    ${undefined} | ${'undefined'}
  `('$number', ({ number, expected }) => {
    it(`formats the number correctly`, () => {
      const result = formatNumber(number);
      expect(result).toEqual(expected);
    });
  });

  describe('fractionDigits', () => {
    it('formats the number with one fraction digit by default', () => {
      const result = formatNumber(1234.5678);
      expect(result).toEqual('1.2k');
    });

    it('formats the number with the specified fraction digits', () => {
      const result = formatNumber(1234.5678, 2);
      expect(result).toEqual('1.23k');
    });
  });
});

describe('ensureAbsoluteCustomerPortalUrl', () => {
  beforeEach(() => {
    window.gon = {
      subscriptions_url: 'https://customers.gitlab.com/',
    };
  });

  it('will return absolute URL as is', () => {
    const absoluteUrl = 'https://customers.gitlab.com/subscriptions/A-S042/usage';

    expect(ensureAbsoluteCustomerPortalUrl(absoluteUrl)).toBe(absoluteUrl);
  });

  it('will turn a relative URL into absolute', () => {
    const relativeUrl = '/subscriptions/A-S042/usage';

    expect(ensureAbsoluteCustomerPortalUrl(relativeUrl)).toBe(
      'https://customers.gitlab.com/subscriptions/A-S042/usage',
    );
  });
});
