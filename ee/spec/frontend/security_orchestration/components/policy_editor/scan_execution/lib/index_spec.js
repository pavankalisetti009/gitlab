import {
  DEFAULT_SCAN_EXECUTION_POLICY,
  DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE,
  DEFAULT_SCAN_EXECUTION_POLICY_OPTIMIZED,
  DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE_OPTIMIZED,
  getPolicyYaml,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/lib';
import { isGroup } from 'ee/security_orchestration/components/utils';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

describe('getPolicyYaml', () => {
  let originalGon;

  beforeEach(() => {
    originalGon = window.gon;
    window.gon = { features: {} };
  });

  afterEach(() => {
    window.gon = originalGon;
  });

  describe('with feature flag disabled', () => {
    beforeEach(() => {
      window.gon.features = { flexibleScanExecutionPolicy: false };
    });

    it.each`
      namespaceType              | expected
      ${NAMESPACE_TYPES.PROJECT} | ${DEFAULT_SCAN_EXECUTION_POLICY}
      ${NAMESPACE_TYPES.GROUP}   | ${DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE}
    `('returns the standard yaml for $namespaceType namespace', ({ namespaceType, expected }) => {
      expect(getPolicyYaml({ isGroup: isGroup(namespaceType) })).toEqual(expected);
    });
  });

  describe('with feature flag enabled', () => {
    beforeEach(() => {
      window.gon.features = { flexibleScanExecutionPolicy: true };
    });

    it.each`
      namespaceType              | expected
      ${NAMESPACE_TYPES.PROJECT} | ${DEFAULT_SCAN_EXECUTION_POLICY_OPTIMIZED}
      ${NAMESPACE_TYPES.GROUP}   | ${DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE_OPTIMIZED}
    `('returns the optimized yaml for $namespaceType namespace', ({ namespaceType, expected }) => {
      expect(getPolicyYaml({ isGroup: isGroup(namespaceType) })).toEqual(expected);
    });
  });
});
