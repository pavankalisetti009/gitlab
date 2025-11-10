import { __, s__ } from '~/locale';

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
    icon: 'pause',
    color: 'neutral',
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

// Values match `EVENT_TYPES` in ee/app/models/ai/flow_trigger.rb:
// https://gitlab.com/gitlab-org/gitlab/-/blob/779eacdc0e752adfe66a477c4fa60dd9fed814eb/ee/app/models/ai/flow_trigger.rb#L7
export const FLOW_TRIGGER_TYPES = [
  {
    text: __('Mention'),
    help: s__(
      'AICatalog|Trigger this flow when the service account user is mentioned in an issue or merge request.',
    ),
    value: 'mention',
  },
  {
    text: __('Assign'),
    help: s__(
      'AICatalog|Trigger this flow when the service account user is assigned to issue or merge request.',
    ),
    value: 'assign',
  },
  {
    text: __('Assign reviewer'),
    help: s__(
      'AICatalog|Trigger this flow when the service account user is assigned as a reviewer to a merge request.',
    ),
    value: 'assign_reviewer',
  },
];

export const DEFAULT_AGENT_PLATFORM_PAGINATION_VARIABLES = {
  first: 20,
  before: null,
  after: null,
  last: null,
};
