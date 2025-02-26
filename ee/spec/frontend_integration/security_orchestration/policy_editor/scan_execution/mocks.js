import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import { fromYaml } from 'ee/security_orchestration/components/utils';

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

const mockScanExecutionManifestParsed = `scan_execution_policy:
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

export const mockDastActionScanExecutionManifest = `scan_execution_policy:
  - name: ''
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
`;

export const mockGroupDastActionScanExecutionManifest = `scan_execution_policy:
  - name: ''
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
`;

export const mockActionsVariablesScanExecutionManifest = `scan_execution_policy:
  - name: ''
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
`;

export const createScanActionScanExecutionManifest = (scanType, parsed = false) => {
  const parser = parsed ? mockScanExecutionManifestParsed : mockScanExecutionManifest;
  return parser.replace('scan: secret_detection', `scan: ${scanType}`);
};

export const mockScheduleScanExecutionManifest = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
    rules:
      - type: schedule
        branches: []
        cadence: 0 0 * * *
    actions:
      - scan: secret_detection
`;

export const mockScanExecutionObject = fromYaml({
  manifest: mockScanExecutionManifest,
  type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
});
