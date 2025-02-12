import { removeGroupSetting } from '../utils';

const putPolicyScopeComplianceFrameworksToEndOfYaml = (yaml) =>
  yaml
    .replace('\npolicy_scope:\n  compliance_frameworks:\n    - id: 1\n    - id: 2', '')
    .concat('policy_scope:\n  compliance_frameworks:\n    - id: 1\n    - id: 2\n');

const putPolicyScopeProjectsToEndOfYaml = (yaml) =>
  yaml
    .replace('\npolicy_scope:\n  projects:\n    excluding:\n      - id: 1\n      - id: 2', '')
    .concat('policy_scope:\n  projects:\n    excluding:\n      - id: 1\n      - id: 2\n');

const GROUP_SETTINGS = `approval_settings:
  block_branch_modification: true
  block_group_branch_modification: true
  prevent_pushing_and_force_pushing: true
  prevent_approval_by_author: true
  prevent_approval_by_commit_author: true
  remove_approvals_with_new_commit: true
  require_password_to_approve: false
`;

const FALLBACK = `fallback_behavior:
  fail: closed
`;

const TYPE = `type: approval_policy
`;

export const mockScanExecutionActionManifest = `name: ''
description: ''
enabled: true
policy_scope:
  compliance_frameworks:
    - id: 1
    - id: 2
rules:
  - type: pipeline
    branches:
      - '*'
actions:
  - scan: secret_detection
type: scan_execution_policy
`;

export const mockScanExecutionActionProjectManifest = putPolicyScopeComplianceFrameworksToEndOfYaml(
  mockScanExecutionActionManifest,
);

export const mockPipelineExecutionActionManifest = `name: ''
description: ''
enabled: true
pipeline_config_strategy: inject_policy
content:
  include:
    - project: ''
type: pipeline_execution_policy
policy_scope:
  compliance_frameworks:
    - id: 1
    - id: 2
`;

export const mockApprovalActionGroupManifest = `name: ''
description: ''
enabled: true
policy_scope:
  compliance_frameworks:
    - id: 1
    - id: 2
rules:
  - type: ''
actions:
  - type: require_approval
    approvals_required: 1
  - type: send_bot_message
    enabled: true
`
  .concat(GROUP_SETTINGS)
  .concat(FALLBACK)
  .concat(TYPE);

export const mockApprovalActionProjectManifest = removeGroupSetting(
  putPolicyScopeComplianceFrameworksToEndOfYaml(mockApprovalActionGroupManifest),
);

export const EXCLUDING_PROJECTS_MOCKS = {
  SCAN_EXECUTION: `name: ''
description: ''
enabled: true
policy_scope:
  projects:
    excluding:
      - id: 1
      - id: 2
rules:
  - type: pipeline
    branches:
      - '*'
actions:
  - scan: secret_detection
type: scan_execution_policy
`,
  PIPELINE_EXECUTION: `name: ''
description: ''
enabled: true
pipeline_config_strategy: inject_policy
content:
  include:
    - project: ''
policy_scope:
  projects:
    excluding:
      - id: 1
      - id: 2
type: pipeline_execution_policy
`,
  APPROVAL_POLICY: `name: ''
description: ''
enabled: true
policy_scope:
  projects:
    excluding:
      - id: 1
      - id: 2
rules:
  - type: ''
actions:
  - type: require_approval
    approvals_required: 1
  - type: send_bot_message
    enabled: true
`
    .concat(GROUP_SETTINGS)
    .concat(FALLBACK)
    .concat(TYPE),
};

export const EXCLUDING_PROJECTS_PROJECTS_LEVEL_MOCKS = {
  SCAN_EXECUTION: putPolicyScopeProjectsToEndOfYaml(EXCLUDING_PROJECTS_MOCKS.SCAN_EXECUTION),
  PIPELINE_EXECUTION: putPolicyScopeProjectsToEndOfYaml(
    EXCLUDING_PROJECTS_MOCKS.PIPELINE_EXECUTION,
  ),
  APPROVAL_POLICY: removeGroupSetting(
    putPolicyScopeProjectsToEndOfYaml(EXCLUDING_PROJECTS_MOCKS.APPROVAL_POLICY),
  ),
};

const replaceProjectKey = (value) => value.replace('excluding', 'including');

export const INCLUDING_PROJECTS_MOCKS = {
  SCAN_EXECUTION: replaceProjectKey(EXCLUDING_PROJECTS_MOCKS.SCAN_EXECUTION),
  PIPELINE_EXECUTION: replaceProjectKey(EXCLUDING_PROJECTS_MOCKS.PIPELINE_EXECUTION),
  APPROVAL_POLICY: replaceProjectKey(EXCLUDING_PROJECTS_MOCKS.APPROVAL_POLICY),
};

export const INCLUDING_PROJECTS_PROJECTS_LEVEL_MOCKS = {
  SCAN_EXECUTION: replaceProjectKey(EXCLUDING_PROJECTS_PROJECTS_LEVEL_MOCKS.SCAN_EXECUTION),
  PIPELINE_EXECUTION: replaceProjectKey(EXCLUDING_PROJECTS_PROJECTS_LEVEL_MOCKS.PIPELINE_EXECUTION),
  APPROVAL_POLICY: replaceProjectKey(EXCLUDING_PROJECTS_PROJECTS_LEVEL_MOCKS.APPROVAL_POLICY),
};

const removeExcludingProjects = (value) =>
  value.replace(
    'projects:\n    excluding:\n      - id: 1\n      - id: 2',
    'projects:\n    excluding: []',
  );

export const INCLUDING_GROUPS_WITH_EXCEPTIONS_MOCKS = {
  SCAN_EXECUTION: `name: ''
description: ''
enabled: true
policy_scope:
  groups:
    including:
      - id: 1
      - id: 2
  projects:
    excluding: []
rules:
  - type: pipeline
    branches:
      - '*'
actions:
  - scan: secret_detection
type: scan_execution_policy
`,
  PIPELINE_EXECUTION: `name: ''
description: ''
enabled: true
pipeline_config_strategy: inject_policy
content:
  include:
    - project: ''
type: pipeline_execution_policy
policy_scope:
  groups:
    including:
      - id: 1
      - id: 2
  projects:
    excluding: []
`,
  APPROVAL_POLICY: `name: ''
description: ''
enabled: true
policy_scope:
  groups:
    including:
      - id: 1
      - id: 2
  projects:
    excluding: []
rules:
  - type: ''
actions:
  - type: require_approval
    approvals_required: 1
  - type: send_bot_message
    enabled: true
`
    .concat(GROUP_SETTINGS)
    .concat(FALLBACK)
    .concat(TYPE),
};

export const INCLUDING_GROUPS_MOCKS = {
  SCAN_EXECUTION: removeExcludingProjects(INCLUDING_GROUPS_WITH_EXCEPTIONS_MOCKS.SCAN_EXECUTION),
  PIPELINE_EXECUTION: removeExcludingProjects(
    INCLUDING_GROUPS_WITH_EXCEPTIONS_MOCKS.PIPELINE_EXECUTION,
  ),
  APPROVAL_POLICY: removeExcludingProjects(INCLUDING_GROUPS_WITH_EXCEPTIONS_MOCKS.APPROVAL_POLICY),
};

export const EXCLUDING_PROJECTS_ON_PROJECT_LEVEL = `name: ''
description: ''
enabled: true
pipeline_config_strategy: inject_policy
content:
  include:
    - project: ''
type: pipeline_execution_policy
policy_scope:
  projects:
    excluding:
      - id: 1
      - id: 2
`;

export const INCLUDING_PROJECTS_ON_PROJECT_LEVEL = replaceProjectKey(
  EXCLUDING_PROJECTS_ON_PROJECT_LEVEL,
);
