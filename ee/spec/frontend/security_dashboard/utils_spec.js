import { autoDismissVulnerabilityPoliciesEnabled } from 'ee/security_dashboard/utils';

describe('autoDismissVulnerabilityPoliciesEnabled', () => {
  it.each`
    autoDismissVulnerabilityPolicies | policyAutoDismissedEsFilter | expected
    ${false}                         | ${false}                    | ${false}
    ${false}                         | ${true}                     | ${false}
    ${true}                          | ${false}                    | ${false}
    ${true}                          | ${true}                     | ${true}
  `(
    'returns correct output when autoDismissVulnerabilityPolicies=$autoDismissVulnerabilityPolicies and policyAutoDismissedEsFilter=$policyAutoDismissedEsFilter',
    ({ autoDismissVulnerabilityPolicies, policyAutoDismissedEsFilter, expected }) => {
      window.gon.features = { autoDismissVulnerabilityPolicies, policyAutoDismissedEsFilter };
      expect(autoDismissVulnerabilityPoliciesEnabled()).toBe(expected);
    },
  );
});
