import {
  isCustomEpssValue,
  extractPercentValue,
  convertToPercentString,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/utils';
import {
  LOW_RISK,
  MODERATE_RISK,
  HIGH_RISK,
  CRITICAL_RISK,
  CUSTOM_VALUE,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';

describe('scan_filters/utils', () => {
  describe('extractPercentValue', () => {
    describe('valid percentage strings', () => {
      it.each([
        { input: 'Low Risk (10%)', expected: 0.1 },
        { input: 'Moderate Risk (50%)', expected: 0.5 },
        { input: 'High Risk (80%)', expected: 0.8 },
        { input: 'Critical Risk (100%)', expected: 1.0 },
        { input: 'Custom (25%)', expected: 0.25 },
        { input: 'Test (0%)', expected: 0.0 },
        { input: 'Something (99.5%)', expected: 0.995 },
        { input: 'Value (0.1%)', expected: 0.001 },
      ])('extracts percentage from "$input"', ({ input, expected }) => {
        expect(extractPercentValue(input)).toBe(expected);
      });
    });

    describe('edge cases and invalid inputs', () => {
      it.each([
        { input: '', expected: undefined },
        { input: null, expected: undefined },
        { input: undefined, expected: undefined },
        { input: 'No percentage here', expected: undefined },
        { input: '50%', expected: undefined }, // Missing parentheses
        { input: '(50)', expected: undefined }, // Missing % symbol
        { input: 'Text (abc%)', expected: undefined }, // Non-numeric value
        { input: 'Multiple (10%) and (20%)', expected: 0.1 }, // Takes first match
        { input: 'Negative (-10%)', expected: undefined }, // Handles negative
        { input: 'Large (1000%)', expected: 10.0 }, // Handles large values
        { input: 'Empty ()', expected: undefined }, // Empty parentheses
        { input: 'Just (%)', expected: undefined }, // Just % symbol
        { input: 'Decimal (12.34%)', expected: 0.1234 },
        { input: 'Zero (0.0%)', expected: 0.0 },
      ])('handles invalid input "$input"', ({ input, expected }) => {
        expect(extractPercentValue(input)).toBe(expected);
      });
    });
  });

  describe('convertToPercentString', () => {
    describe('predefined risk levels', () => {
      it.each([
        { input: 0.1, expected: LOW_RISK },
        { input: 0.5, expected: MODERATE_RISK },
        { input: 0.8, expected: HIGH_RISK },
        { input: 1.0, expected: CRITICAL_RISK },
      ])('converts $input to predefined risk level', ({ input, expected }) => {
        expect(convertToPercentString(input)).toBe(expected);
      });
    });

    describe('custom values', () => {
      it.each([
        { input: 0.25, expected: CUSTOM_VALUE },
        { input: 0.75, expected: CUSTOM_VALUE },
        { input: 0.33, expected: CUSTOM_VALUE },
        { input: 0.99, expected: CUSTOM_VALUE },
        { input: 0.01, expected: LOW_RISK },
        { input: 0.123456, expected: CUSTOM_VALUE },
      ])('converts $input to custom value', ({ input, expected }) => {
        expect(convertToPercentString(input)).toBe(expected);
      });
    });

    describe('edge cases and invalid inputs', () => {
      it.each([
        { input: 0, expected: undefined },
        { input: 0.0, expected: undefined },
        { input: -0.1, expected: CUSTOM_VALUE }, // Negative values
        { input: 1.5, expected: CUSTOM_VALUE }, // Values > 1
        { input: NaN, expected: undefined },
        { input: Infinity, expected: CUSTOM_VALUE },
        { input: -Infinity, expected: CUSTOM_VALUE },
        { input: null, expected: undefined },
        { input: undefined, expected: undefined },
        { input: '', expected: undefined },
        { input: 'string', expected: undefined },
        { input: {}, expected: undefined },
        { input: [], expected: undefined },
        { input: true, expected: CRITICAL_RISK }, // Boolean true converts to 1
        { input: false, expected: undefined }, // Boolean false converts to 0
      ])('handles edge case input $input', ({ input, expected }) => {
        expect(convertToPercentString(input)).toBe(expected);
      });
    });
  });

  describe('isCustomEpssValue', () => {
    it.each([
      { input: 0.1, expected: false },
      { input: 0.2, expected: true },
      { input: 0.3, expected: true },
      { input: 0.4, expected: true },
      { input: 0.5, expected: false },
      { input: 0.6, expected: true },
      { input: 0.7, expected: true },
      { input: 0.8, expected: false },
      { input: 0.9, expected: true },
      { input: 1.0, expected: false },
      { input: 1.1, expected: true },
      { input: undefined, expected: false },
      { input: null, expected: false },
      { input: -1, expected: true },
      { input: NaN, expected: false },
      { input: {}, expected: false },
      { input: [], expected: false },
      { input: 'string', expected: false },
    ])('checks custom percent strings', ({ input, expected }) => {
      expect(isCustomEpssValue(input)).toBe(expected);
    });
  });
});
