import { numberToMetricPrefix } from '~/lib/utils/number_utils';

export const fillUsageValues = (usage) => {
  const {
    creditsUsed,
    totalCredits,
    monthlyCommitmentCreditsUsed,
    monthlyWaiverCreditsUsed,
    overageCreditsUsed,
  } = usage ?? {};

  return {
    creditsUsed: creditsUsed ?? 0,
    totalCredits: totalCredits ?? 0,
    monthlyCommitmentCreditsUsed: monthlyCommitmentCreditsUsed ?? 0,
    monthlyWaiverCreditsUsed: monthlyWaiverCreditsUsed ?? 0,
    overageCreditsUsed: overageCreditsUsed ?? 0,
  };
};

/**
 * Formats number with a fixed fraction digits if below 1000, or with a metric prefix
 *
 * @param {number} value
 * @returns string
 */
export const formatNumber = (value) => {
  if (value === 0) return '0';
  if (!value) return `${value}`;
  if (value < 1000) {
    if (Number.isInteger(value)) return `${value}`;
    return value.toFixed(1);
  }
  return numberToMetricPrefix(value);
};
