import {
  validateSourceFilter,
  validateTypeFilter,
  extractTypeParameter,
  extractSourceParameter,
} from 'ee/security_orchestration/components/policies/utils';
import {
  POLICY_SOURCE_OPTIONS,
  POLICY_TYPE_FILTER_OPTIONS,
} from 'ee/security_orchestration/components/policies/constants';

describe('utils', () => {
  describe('validateSourceFilter', () => {
    it.each`
      value                                                  | valid
      ${POLICY_SOURCE_OPTIONS.ALL.value}                     | ${true}
      ${POLICY_SOURCE_OPTIONS.INHERITED.value}               | ${true}
      ${POLICY_SOURCE_OPTIONS.DIRECT.value}                  | ${true}
      ${'invalid key'}                                       | ${false}
      ${''}                                                  | ${false}
      ${undefined}                                           | ${false}
      ${null}                                                | ${false}
      ${{}}                                                  | ${false}
      ${0}                                                   | ${false}
      ${POLICY_SOURCE_OPTIONS.ALL.value.toLowerCase()}       | ${true}
      ${POLICY_SOURCE_OPTIONS.INHERITED.value.toLowerCase()} | ${true}
      ${POLICY_SOURCE_OPTIONS.DIRECT.value.toLowerCase()}    | ${true}
    `('should validate source filters', ({ value, valid }) => {
      expect(validateSourceFilter(value)).toBe(valid);
    });
  });

  describe('validateTypeFilter', () => {
    it.each`
      value                                                                | valid
      ${POLICY_TYPE_FILTER_OPTIONS.ALL.value}                              | ${true}
      ${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value}                   | ${true}
      ${POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value}                         | ${true}
      ${''}                                                                | ${true}
      ${'invalid key'}                                                     | ${false}
      ${undefined}                                                         | ${false}
      ${null}                                                              | ${false}
      ${{}}                                                                | ${false}
      ${0}                                                                 | ${false}
      ${POLICY_TYPE_FILTER_OPTIONS.ALL.value.toLowerCase()}                | ${true}
      ${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value.toLowerCase()}     | ${true}
      ${POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value.toLowerCase()}           | ${true}
      ${POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION.value.toLowerCase()} | ${true}
    `('should validate type filters', ({ value, valid }) => {
      expect(validateTypeFilter(value)).toBe(valid);
    });
  });

  describe('extractTypeParameter', () => {
    it.each`
      type                                                             | output
      ${POLICY_TYPE_FILTER_OPTIONS.ALL.value}                          | ${''}
      ${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value}               | ${'SCAN_EXECUTION'}
      ${POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value}                     | ${'APPROVAL'}
      ${''}                                                            | ${''}
      ${'invalid key'}                                                 | ${''}
      ${undefined}                                                     | ${''}
      ${null}                                                          | ${''}
      ${{}}                                                            | ${''}
      ${0}                                                             | ${''}
      ${POLICY_TYPE_FILTER_OPTIONS.ALL.value.toLowerCase()}            | ${''}
      ${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value.toLowerCase()} | ${'SCAN_EXECUTION'}
      ${POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value.toLowerCase()}       | ${'APPROVAL'}
      ${'scan_result'}                                                 | ${'APPROVAL'}
    `('should extract valid type parameter', ({ type, output }) => {
      expect(extractTypeParameter(type)).toBe(output);
    });
  });

  describe('extractSourceParameter', () => {
    it.each`
      source                                                 | output
      ${POLICY_SOURCE_OPTIONS.ALL.value}                     | ${'INHERITED'}
      ${POLICY_SOURCE_OPTIONS.INHERITED.value}               | ${'INHERITED_ONLY'}
      ${POLICY_SOURCE_OPTIONS.DIRECT.value}                  | ${'DIRECT'}
      ${'invalid key'}                                       | ${'INHERITED'}
      ${''}                                                  | ${'INHERITED'}
      ${undefined}                                           | ${'INHERITED'}
      ${null}                                                | ${'INHERITED'}
      ${{}}                                                  | ${'INHERITED'}
      ${0}                                                   | ${'INHERITED'}
      ${POLICY_SOURCE_OPTIONS.ALL.value.toLowerCase()}       | ${'INHERITED'}
      ${POLICY_SOURCE_OPTIONS.INHERITED.value.toLowerCase()} | ${'INHERITED_ONLY'}
      ${POLICY_SOURCE_OPTIONS.DIRECT.value.toLowerCase()}    | ${'DIRECT'}
    `('should validate source filters', ({ source, output }) => {
      expect(extractSourceParameter(source)).toBe(output);
    });
  });
});
