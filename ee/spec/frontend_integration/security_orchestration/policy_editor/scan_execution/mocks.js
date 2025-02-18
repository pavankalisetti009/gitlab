import { fromYaml } from 'ee/security_orchestration/components/policy_editor/scan_execution/lib';

export const mockScanExecutionManifest = `scan_execution_policy:
- name: ''
  description: ''
  enabled: true
  rules:
  - type: pipeline
    branches:
      - '*'
  actions:
    - scan: secret_detection
`;

const mockScanExecutionManifestParsed = `name: ''
description: ''
enabled: true
rules:
  - type: pipeline
    branches:
      - '*'
actions:
  - scan: secret_detection
type: scan_execution_policy
`;

export const mockDastActionScanExecutionManifest = `name: ''
description: ''
enabled: true
rules:
  - type: pipeline
    branches:
      - '*'
actions:
  - scan: dast
    site_profile: ''
    scanner_profile: ''
type: scan_execution_policy
`;

export const mockGroupDastActionScanExecutionManifest = `name: ''
description: ''
enabled: true
policy_scope:
  projects:
    excluding: []
rules:
  - type: pipeline
    branches:
      - '*'
actions:
  - scan: dast
    site_profile: ''
    scanner_profile: ''
type: scan_execution_policy
`;

export const mockActionsVariablesScanExecutionManifest = `name: ''
description: ''
enabled: true
rules:
  - type: pipeline
    branches:
      - '*'
actions:
  - scan: secret_detection
    variables:
      '': ''
type: scan_execution_policy
`;

export const createScanActionScanExecutionManifest = (scanType, parsed = false) => {
  const parser = parsed ? mockScanExecutionManifestParsed : mockScanExecutionManifest;
  return parser.replace('scan: secret_detection', `scan: ${scanType}`);
};

export const mockScheduleScanExecutionManifest = `name: ''
description: ''
enabled: true
rules:
  - type: schedule
    branches: []
    cadence: 0 0 * * *
actions:
  - scan: secret_detection
type: scan_execution_policy
`;

export const mockScanExecutionObject = fromYaml({ manifest: mockScanExecutionManifest });
