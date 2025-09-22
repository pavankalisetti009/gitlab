import {
  DEFAULT_SCAN_RESULT_POLICY,
  DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS,
  DEFAULT_SCAN_RESULT_POLICY_WITH_WARN_ENFORCEMENT,
  DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS_WITH_WARN_ENFORCEMENT,
  getPolicyYaml,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import { isGroup } from 'ee/security_orchestration/components/utils';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

describe('getPolicyYaml', () => {
  describe('without feature flag', () => {
    it.each`
      namespaceType              | expected
      ${NAMESPACE_TYPES.PROJECT} | ${DEFAULT_SCAN_RESULT_POLICY}
      ${NAMESPACE_TYPES.GROUP}   | ${DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS}
    `('returns the yaml for the $namespaceType namespace', ({ namespaceType, expected }) => {
      expect(getPolicyYaml({ isGroup: isGroup(namespaceType) })).toEqual(expected);
    });
  });

  describe('with securityPolicyApprovalWarnMode feature flag enabled', () => {
    beforeEach(() => {
      window.gon = {
        features: {
          securityPolicyApprovalWarnMode: true,
        },
      };
    });

    it.each`
      namespaceType              | expected
      ${NAMESPACE_TYPES.PROJECT} | ${DEFAULT_SCAN_RESULT_POLICY_WITH_WARN_ENFORCEMENT}
      ${NAMESPACE_TYPES.GROUP}   | ${DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS_WITH_WARN_ENFORCEMENT}
    `(
      'returns the yaml with warn enforcement for the $namespaceType namespace',
      ({ namespaceType, expected }) => {
        expect(getPolicyYaml({ isGroup: isGroup(namespaceType) })).toEqual(expected);
      },
    );
  });
});
