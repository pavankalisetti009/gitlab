export const isPolicyViolationFilterEnabled = () => {
  return (
    window.gon?.abilities?.accessAdvancedVulnerabilityManagement &&
    window.gon?.features?.securityPolicyApprovalWarnMode &&
    window.gon?.features?.policyViolationsEsFilter
  );
};
