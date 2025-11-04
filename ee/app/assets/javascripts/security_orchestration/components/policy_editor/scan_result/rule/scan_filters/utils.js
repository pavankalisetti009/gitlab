import { LOW_RISK, MODERATE_RISK, HIGH_RISK, CRITICAL_RISK, CUSTOM_VALUE } from './constants';

const PREDEFINED_VALUES = [LOW_RISK, HIGH_RISK, MODERATE_RISK, CRITICAL_RISK];

/**
 * Extract percent value from string like Critical Risk (100%)
 * It would result into 100 and returns 1
 * @param value
 * @returns {undefined|number}
 */
export const extractPercentValue = (value = '') => {
  if (!value) return undefined;

  const match = value.match(/\((\d+(?:\.\d+)?)%\)/);

  if (match) {
    const number = parseFloat(match[1]);
    return number / 100;
  }

  return undefined;
};

/**
 * Based on input Like 1|0.5|0.3 it would return one of
 * predefined values like Critical Risk (100%)
 * @param value
 * @returns {undefined|*}
 */
export const convertToPercentString = (value) => {
  if (!value || Number.isNaN(Number(value))) return undefined;

  const convertedPercent = value * 100;
  if (convertedPercent === 0) return undefined;

  return PREDEFINED_VALUES.find((v) => v.includes(convertedPercent.toString())) || CUSTOM_VALUE;
};

/**
 * If value is not in the list of predefined values
 * it means it is custom value
 * @param value
 * @returns {boolean}
 */
export const isCustomEpssValue = (value) => {
  if (!value || Number.isNaN(Number(value))) return false;

  const convertedPercent = value * 100;
  if (convertedPercent === 0) return false;

  return PREDEFINED_VALUES.find((v) => v.includes(convertedPercent.toString())) === undefined;
};
