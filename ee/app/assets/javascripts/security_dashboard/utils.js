export const isPolicyViolationFilterEnabled = () => {
  return (
    window.gon?.abilities?.accessAdvancedVulnerabilityManagement &&
    window.gon?.features?.securityPolicyApprovalWarnMode &&
    window.gon?.features?.policyViolationsEsFilter
  );
};

export const autoDismissVulnerabilityPoliciesEnabled = () => {
  return (
    window.gon?.features?.autoDismissVulnerabilityPolicies &&
    window.gon?.features?.policyAutoDismissedEsFilter
  );
};
