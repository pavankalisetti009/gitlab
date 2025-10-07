import { EXCEPTION_MODE, WARN_MODE } from './constants';

export const getSelectedModeOption = ({ hasBypassPolicies = false, allowBypass = false }) => {
  if (hasBypassPolicies && allowBypass) return '';
  if (hasBypassPolicies) return WARN_MODE;
  if (allowBypass) return EXCEPTION_MODE;
  return '';
};
