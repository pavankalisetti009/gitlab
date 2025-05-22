export { createPolicyObject } from './from_yaml';
export * from './to_yaml';
export * from './rules';
export * from './cron';
export * from './actions';

export const DEFAULT_SCAN_EXECUTION_POLICY_OPTIMIZED = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
    rules:
      - type: pipeline
        branches:
          - '*'
    actions:
      - scan: secret_detection
        template: latest
    skip_ci:
      allowed: true
`;

export const DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE_OPTIMIZED = `scan_execution_policy:
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
      - scan: secret_detection
        template: latest
    skip_ci:
      allowed: true
`;

export const DEFAULT_SCAN_EXECUTION_POLICY = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
    rules:
      - type: pipeline
        branches:
          - '*'
    actions:
      - scan: secret_detection
    skip_ci:
      allowed: true
`;

export const DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE = `scan_execution_policy:
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
      - scan: secret_detection
    skip_ci:
      allowed: true
`;

export const getPolicyYaml = ({ isGroup }) => {
  const { flexibleScanExecutionPolicy } = window.gon?.features || {};

  if (flexibleScanExecutionPolicy) {
    return isGroup
      ? DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE_OPTIMIZED
      : DEFAULT_SCAN_EXECUTION_POLICY_OPTIMIZED;
  }

  return isGroup ? DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE : DEFAULT_SCAN_EXECUTION_POLICY;
};
