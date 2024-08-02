import {
  DEFAULT_SCAN_RESULT_POLICY,
  DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE,
  DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS,
  getPolicyYaml,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import { isGroup } from 'ee/security_orchestration/components/utils';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

describe('getPolicyYaml', () => {
  it.each`
    namespaceType              | withGroupSettings | expected
    ${NAMESPACE_TYPES.GROUP}   | ${false}          | ${DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE}
    ${NAMESPACE_TYPES.PROJECT} | ${false}          | ${DEFAULT_SCAN_RESULT_POLICY}
    ${NAMESPACE_TYPES.GROUP}   | ${true}           | ${DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS}
  `(
    'returns the yaml for the $namespaceType namespace',
    ({ namespaceType, expected, withGroupSettings }) => {
      expect(getPolicyYaml({ isGroup: isGroup(namespaceType), withGroupSettings })).toEqual(
        expected,
      );
    },
  );
});
