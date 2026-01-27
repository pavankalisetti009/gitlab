import { __, s__, sprintf } from '~/locale';

export const AGENTFLOW_TYPE_JENKINS_TO_CI = 'convert_to_gitlab_ci';
export const DUO_AGENTS_PLATFORM_POLLING_INTERVAL = 10000;
export const AGENT_PLATFORM_INDEX_COMPONENT_NAME = 'DuoAgentPlatformIndex';

export const AGENT_PLATFORM_PROJECT_PAGE = 'project';
export const AGENT_PLATFORM_GROUP_PAGE = 'group';
export const AGENT_PLATFORM_USER_PAGE = 'user';

export const AGENT_PLATFORM_STATUS_ICON = {
  CREATED: {
    icon: 'dash-circle',
    color: 'neutral',
  },
  RUNNING: {
    icon: 'play',
    color: 'blue',
  },
  FINISHED: {
    icon: 'check',
    color: 'green',
  },
  PAUSED: {
    icon: 'pause',
    color: 'neutral',
  },
  STOPPED: {
    icon: 'cancel',
    color: 'red',
  },
  INPUT_REQUIRED: {
    icon: 'status',
    color: 'orange',
  },
  PLAN_APPROVAL_REQUIRED: {
    icon: 'status',
    color: 'orange',
  },
  TOOL_CALL_APPROVAL_REQUIRED: {
    icon: 'status',
    color: 'orange',
  },
  FAILED: {
    icon: 'error',
    color: 'red',
  },
};

export const AGENT_PLATFORM_STATUS_BADGE = {
  CREATED: {
    variant: 'neutral',
  },
  RUNNING: {
    variant: 'info',
  },
  FINISHED: {
    variant: 'success',
  },
  PAUSED: {
    variant: 'neutral',
  },
  STOPPED: {
    variant: 'danger',
  },
  INPUT_REQUIRED: {
    variant: 'warning',
  },
  PLAN_APPROVAL_REQUIRED: {
    variant: 'warning',
  },
  TOOL_CALL_APPROVAL_REQUIRED: {
    variant: 'warning',
  },
  FAILED: {
    variant: 'danger',
  },
};

export const FLOW_TRIGGER_TYPE_MENTION = {
  text: __('Mention'),
  createHelp: (itemType) =>
    sprintf(
      s__(
        'AICatalog|Trigger this %{itemType} when the service account user is mentioned in an issue or merge request.',
      ),
      { itemType },
    ),
  value: 'mention',
  valueInt: 0,
  graphQL: 'MENTION',
};

export const FLOW_TRIGGER_TYPE_ASSIGN = {
  text: __('Assign'),
  createHelp: (itemType) =>
    sprintf(
      s__(
        'AICatalog|Trigger this %{itemType} when the service account user is assigned to issue or merge request.',
      ),
      { itemType },
    ),
  value: 'assign',
  valueInt: 1,
  graphQL: 'ASSIGN',
};

export const FLOW_TRIGGER_TYPE_ASSIGN_REVIEWER = {
  text: __('Assign reviewer'),
  createHelp: (itemType) =>
    sprintf(
      s__(
        'AICatalog|Trigger this %{itemType} when the service account user is assigned as a reviewer to a merge request.',
      ),
      { itemType },
    ),
  value: 'assign_reviewer',
  valueInt: 2,
  graphQL: 'ASSIGN_REVIEWER',
};

export const FLOW_TRIGGER_TYPE_PIPELINE_HOOKS = {
  text: __('Pipeline events'),
  createHelp: (itemType) =>
    sprintf(s__('AICatalog|Trigger this %{itemType} when a pipeline status changes.'), {
      itemType,
    }),
  value: 'pipeline_hooks',
  valueInt: 3,
  graphQL: 'PIPELINE_HOOKS',
};

// Values match `EVENT_TYPES` in ee/app/models/ai/flow_trigger.rb:
// https://gitlab.com/gitlab-org/gitlab/-/blob/779eacdc0e752adfe66a477c4fa60dd9fed814eb/ee/app/models/ai/flow_trigger.rb#L7
export const FLOW_TRIGGER_TYPES = [
  FLOW_TRIGGER_TYPE_MENTION,
  FLOW_TRIGGER_TYPE_ASSIGN,
  FLOW_TRIGGER_TYPE_ASSIGN_REVIEWER,
  FLOW_TRIGGER_TYPE_PIPELINE_HOOKS,
];

export const DEFAULT_AGENT_PLATFORM_PAGINATION_VARIABLES = {
  first: 20,
  before: null,
  after: null,
  last: null,
};

// Can cancel only if session is in an active state (not already finished, failed, or stopped)
export const AGENT_PLATFORM_CANCELABLE_STATUSES = [
  'CREATED',
  'RUNNING',
  'PAUSED',
  'INPUT_REQUIRED',
  'PLAN_APPROVAL_REQUIRED',
  'TOOL_CALL_APPROVAL_REQUIRED',
];
