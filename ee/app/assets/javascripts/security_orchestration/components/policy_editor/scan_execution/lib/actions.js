import { uniqueId } from 'lodash';
import { REPORT_TYPE_DAST } from '~/vue_shared/security_reports/constants';

export const buildScannerAction = ({
  scanner,
  siteProfile = '',
  scannerProfile = '',
  id,
  isOptimized = false,
}) => {
  const action = { scan: scanner, id: id ?? uniqueId('action_') };

  if (scanner === REPORT_TYPE_DAST) {
    action.site_profile = siteProfile;
    action.scanner_profile = scannerProfile;
  }

  if (isOptimized) {
    action.template = 'latest';
  }

  return action;
};
