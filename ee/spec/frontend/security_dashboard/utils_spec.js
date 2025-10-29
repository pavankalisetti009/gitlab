import { isPolicyViolationFilterEnabled } from 'ee/security_dashboard/utils';

describe('isPolicyViolationFilterEnabled', () => {
  it.each`
    accessAdvancedVulnerabilityManagement | securityPolicyApprovalWarnMode | policyViolationsEsFilter | expected
    ${true}                               | ${true}                        | ${true}                  | ${true}
    ${true}                               | ${true}                        | ${false}                 | ${false}
    ${true}                               | ${false}                       | ${true}                  | ${false}
    ${true}                               | ${false}                       | ${false}                 | ${false}
    ${false}                              | ${true}                        | ${true}                  | ${false}
    ${false}                              | ${true}                        | ${false}                 | ${false}
    ${false}                              | ${false}                       | ${true}                  | ${false}
    ${false}                              | ${false}                       | ${false}                 | ${false}
  `(
    'returns the correct output when accessAdvancedVulnerabilityManagement=$resolveVulnerabilityWithAi and securityPolicyApprovalWarnMode=$securityPolicyApprovalWarnMode and policyViolationsEsFilter=$policyViolationsEsFilter',
    ({
      accessAdvancedVulnerabilityManagement,
      securityPolicyApprovalWarnMode,
      policyViolationsEsFilter,
      expected,
    }) => {
      window.gon.features = { securityPolicyApprovalWarnMode, policyViolationsEsFilter };
      window.gon.abilities = { accessAdvancedVulnerabilityManagement };

      expect(isPolicyViolationFilterEnabled()).toBe(expected);
    },
  );
});
