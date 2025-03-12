import { s__ } from '~/locale';

const SAST_LABEL = s__('SecurityInventory|SAST');
const DAST_LABEL = s__('SecurityInventory|DAST');
const SAST_IAC_LABEL = s__('SecurityInventory|IaC');
const SECRET_DETECTION_LABEL = s__('SecurityInventory|SD');
const DEPENDENCY_SCANNING_LABEL = s__('SecurityInventory|DS');
const CONTAINER_SCANNING_LABEL = s__('SecurityInventory|CS');

export const SCANNERS = [
  {
    scanner: 'SAST',
    label: SAST_LABEL,
  },
  {
    scanner: 'DAST',
    label: DAST_LABEL,
  },
  {
    scanner: 'SAST_IAC',
    label: SAST_IAC_LABEL,
  },
  {
    scanner: 'SECRET_DETECTION',
    label: SECRET_DETECTION_LABEL,
  },
  {
    scanner: 'DEPENDENCY_SCANNING',
    label: DEPENDENCY_SCANNING_LABEL,
  },
  {
    scanner: 'CONTAINER_SCANNING',
    label: CONTAINER_SCANNING_LABEL,
  },
];
