import { isEqual, uniqBy } from 'lodash';
import { REPORT_TYPE_DAST } from '~/vue_shared/security_reports/constants';
import { SELECTION_CONFIG_CUSTOM, SELECTION_CONFIG_DEFAULT } from '../constants';

export { createPolicyObject } from './from_yaml';
export * from './to_yaml';
export * from './rules';
export * from './cron';
export * from './actions';

export const optimizedConfiguration = `    rules:
      - type: pipeline
        branch_type: default
      - type: pipeline
        branch_type: target_default
        pipeline_sources:
          including:
            - merge_request_event
    actions:
      - scan: secret_detection
        template: latest
    skip_ci:
      allowed: true`;

export const DEFAULT_SCAN_EXECUTION_POLICY_OPTIMIZED = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
${optimizedConfiguration}`;

export const DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE_OPTIMIZED = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
    policy_scope:
      projects:
        excluding: []
${optimizedConfiguration}`;

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

export const DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE_WITH_DEFAULT_VARIABLES = `scan_execution_policy:
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
        variables:
          SECURE_ENABLE_LOCAL_CONFIGURATION: 'false'
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

export const OPTIMIZED_RULES = [
  { type: 'pipeline', branch_type: 'default' },
  {
    type: 'pipeline',
    branch_type: 'target_default',
    pipeline_sources: { including: ['merge_request_event'] },
  },
];

// The rules must have two rules that are the optimized. Order does not matter
export const hasOptimizedRules = (rules) => {
  return (
    rules.length === OPTIMIZED_RULES.length &&
    OPTIMIZED_RULES.every((optimizedRule) => {
      return rules.some((rule) => {
        const { id, ...rest } = rule;
        return isEqual(rest, optimizedRule);
      });
    })
  );
};

// Action scans must be unique (e.g. only one of each scan type)
export const hasUniqueScans = (actions) => uniqBy(actions, 'scan').length === actions.length;

//  DAST scans are too complex for the optimized path
export const hasOnlyAllowedScans = (actions) =>
  actions.every(({ scan }) => scan !== REPORT_TYPE_DAST);

// Each action must be optimized (e.g. template: latest only, no runner tags or CI variables)
export const hasSimpleScans = (actions) => {
  const optimizedAction = { template: 'latest' };
  return actions.every((action) => {
    const { id, scan, variables, ...rest } = action;
    return isEqual(rest, optimizedAction);
  });
};

export const getConfiguration = (policy) => {
  const { actions = [], rules = [] } = policy;
  if (
    hasOptimizedRules(rules) &&
    hasOnlyAllowedScans(actions) &&
    hasUniqueScans(actions) &&
    hasSimpleScans(actions)
  ) {
    return SELECTION_CONFIG_DEFAULT;
  }

  return SELECTION_CONFIG_CUSTOM;
};
