import { THOUSAND, MILLION } from '~/lib/utils/constants';
import { isAbsolute, joinPaths } from '~/lib/utils/url_utility';

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
 * @param {number} fractionDigits how many digits to show after the decimal point
 * @returns {string}
 */
export const formatNumber = (value, fractionDigits = 1) => {
  if (value === 0) return '0';
  if (!value) return `${value}`;
  if (value < THOUSAND) {
    if (Number.isInteger(value)) return `${value}`;
    const multiplier = 10 ** fractionDigits;
    return (Math.round(value * multiplier) / multiplier).toFixed(fractionDigits);
  }

  // Handle metric prefix with custom fraction digits
  if (value < MILLION) {
    return `${Number((value / THOUSAND).toFixed(fractionDigits))}k`;
  }
  return `${Number((value / MILLION).toFixed(fractionDigits))}m`;
};

/**
 * Ensures an absolute URL to customers portal
 *
 * @param {string} urlOrPath absolute URL or a path relative to customers portal
 * @returns {string} absolute URL
 */
export const ensureAbsoluteCustomerPortalUrl = (urlOrPath) => {
  if (isAbsolute(urlOrPath)) return urlOrPath;

  return joinPaths(gon.subscriptions_url, urlOrPath);
};
