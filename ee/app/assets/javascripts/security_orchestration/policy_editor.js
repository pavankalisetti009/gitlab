import Vue from 'vue';
import { convertObjectPropsToCamelCase, parseBoolean } from '~/lib/utils/common_utils';
import apolloProvider from 'ee/vue_shared/security_configuration/graphql/provider';
import App from './components/policy_editor/app.vue';
import { DEFAULT_ASSIGNED_POLICY_PROJECT, MAX_SCAN_EXECUTION_ACTION_COUNT } from './constants';
import { decomposeApprovers } from './utils';

export default (el, namespaceType) => {
  if (!el) return null;

  const {
    assignedPolicyProject,
    disableScanPolicyUpdate,
    createAgentHelpPath,
    globalGroupApproversEnabled,
    maxActiveScanExecutionPoliciesReached,
    maxActiveScanResultPoliciesReached,
    maxActivePipelineExecutionPoliciesReached,
    maxScanExecutionPoliciesAllowed,
    maxScanResultPoliciesAllowed,
    maxPipelineExecutionPoliciesAllowed,
    namespaceId,
    namespacePath,
    policiesPath,
    policy,
    policyEditorEmptyStateSvgPath,
    policyType,
    roleApproverTypes,
    rootNamespacePath,
    scanPolicyDocumentationPath,
    scanResultApprovers,
    softwareLicenses,
    timezones,
    actionApprovers,
    maxScanExecutionPolicyActions,
  } = el.dataset;

  let parsedAssignedPolicyProject;

  try {
    parsedAssignedPolicyProject = convertObjectPropsToCamelCase(JSON.parse(assignedPolicyProject));
  } catch {
    parsedAssignedPolicyProject = DEFAULT_ASSIGNED_POLICY_PROJECT;
  }

  let parsedSoftwareLicenses;
  let parsedTimezones;

  try {
    parsedSoftwareLicenses = JSON.parse(softwareLicenses).map((license) => {
      return { value: license, text: license };
    });
  } catch {
    parsedSoftwareLicenses = [];
  }

  let scanResultPolicyApprovers;
  let parsedActionApprovers;

  try {
    scanResultPolicyApprovers = decomposeApprovers(
      JSON.parse(scanResultApprovers).map((approver) => {
        return typeof approver === 'object' ? convertObjectPropsToCamelCase(approver) : approver;
      }),
    );
  } catch {
    scanResultPolicyApprovers = {};
  }

  try {
    parsedActionApprovers = JSON.parse(actionApprovers);
  } catch {
    parsedActionApprovers = [];
  }

  try {
    parsedTimezones = JSON.parse(timezones);
  } catch {
    parsedTimezones = [];
  }

  const count = parseInt(maxScanExecutionPolicyActions, 10);
  const parsedMaxScanExecutionPolicyActions = Number.isNaN(count)
    ? MAX_SCAN_EXECUTION_ACTION_COUNT
    : count;

  return new Vue({
    el,
    apolloProvider,
    provide: {
      actionApprovers: parsedActionApprovers,
      createAgentHelpPath,
      disableScanPolicyUpdate: parseBoolean(disableScanPolicyUpdate),
      globalGroupApproversEnabled: parseBoolean(globalGroupApproversEnabled),
      maxActiveScanExecutionPoliciesReached: parseBoolean(maxActiveScanExecutionPoliciesReached),
      maxActivePipelineExecutionPoliciesReached: parseBoolean(
        maxActivePipelineExecutionPoliciesReached,
      ),
      maxActiveScanResultPoliciesReached: parseBoolean(maxActiveScanResultPoliciesReached),
      maxScanExecutionPoliciesAllowed,
      maxScanResultPoliciesAllowed,
      maxPipelineExecutionPoliciesAllowed,
      namespaceId,
      namespacePath,
      namespaceType,
      policyEditorEmptyStateSvgPath,
      policyType,
      policiesPath,
      roleApproverTypes: JSON.parse(roleApproverTypes),
      rootNamespacePath,
      scanPolicyDocumentationPath,
      scanResultPolicyApprovers,
      parsedSoftwareLicenses,
      timezones: parsedTimezones,
      existingPolicy: policy ? { type: policyType, ...JSON.parse(policy) } : undefined,
      assignedPolicyProject: parsedAssignedPolicyProject,
      maxScanExecutionPolicyActions: parsedMaxScanExecutionPolicyActions,
    },
    render(createElement) {
      return createElement(App);
    },
  });
};
