import { EXCEPTION_MODE, WARN_MODE } from './constants';

export const getSelectedModeOption = ({ securityPoliciesPath = '', allowBypass = false }) => {
  if (securityPoliciesPath && allowBypass) return '';
  if (securityPoliciesPath) return WARN_MODE;
  if (allowBypass) return EXCEPTION_MODE;
  return '';
};
