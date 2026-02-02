export const autoDismissVulnerabilityPoliciesEnabled = () => {
  return (
    window.gon?.features?.autoDismissVulnerabilityPolicies &&
    window.gon?.features?.policyAutoDismissedEsFilter
  );
};
