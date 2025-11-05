import { s__ } from '~/locale';
import { humanize } from '~/lib/utils/text_utility';
import { AGENT_PLATFORM_STATUS_ICON } from './constants';

export const formatAgentDefinition = (agentDefinition) => {
  return humanize(agentDefinition || s__('DuoAgentsPlatform|Agent session'));
};

export const formatAgentFlowName = (agentDefinition, id) => {
  return `${formatAgentDefinition(agentDefinition)} #${id}`;
};

export const formatAgentStatus = (status) => {
  return status ? humanize(status.toLowerCase()) : s__('DuoAgentsPlatform|Unknown');
};

export const getAgentStatusIcon = (status) => {
  return AGENT_PLATFORM_STATUS_ICON[status] || AGENT_PLATFORM_STATUS_ICON.CREATED;
};

export const parseJsonProperty = (value) => {
  if (typeof value !== 'string') return value;

  try {
    return JSON.parse(value);
  } catch (error) {
    return value;
  }
};

export const getNamespaceDatasetProperties = (dataset, properties, jsonProperties = []) => {
  const allProperties = [...properties, ...jsonProperties];
  return allProperties.reduce((acc, prop) => {
    const value = dataset[prop];

    if (jsonProperties.includes(prop)) {
      acc[prop] = parseJsonProperty(value);
    } else {
      acc[prop] = value;
    }
    return acc;
  }, {});
};

export const getToolData = (toolMessage) => {
  const toolName = toolMessage?.tool_info?.name;

  const toolMap = {
    read_file: { icon: 'eye', title: s__('DuoAgentsPlatform|Read file'), level: 0 },
    write_file: { icon: 'pencil', title: s__('DuoAgentsPlatform|Write file'), level: 1 },
    edit_file: { icon: 'pencil', title: s__('DuoAgentsPlatform|Edit file'), level: 1 },
    create_file_with_contents: {
      icon: 'pencil',
      title: s__('DuoAgentsPlatform|Create file'),
      level: 1,
    },
    grep: { icon: 'search', title: s__('DuoAgentsPlatform|Search'), level: 0 },
    grep_files: { icon: 'search', title: s__('DuoAgentsPlatform|Search files'), level: 0 },
    list_files: { icon: 'search', title: s__('DuoAgentsPlatform|List files'), level: 0 },
    list_dir: { icon: 'folder-open', title: s__('DuoAgentsPlatform|List directory'), level: 0 },
    gitlab_issue_search: {
      icon: 'search',
      title: s__('DuoAgentsPlatform|Search issues'),
      level: 0,
    },
    get_issue: { icon: 'issue-type-issue', title: s__('DuoAgentsPlatform|Get issue'), level: 0 },
    create_merge_request: {
      icon: 'git-merge',
      title: s__('DuoAgentsPlatform|Create merge request'),
      level: 1,
    },
    list_issue_notes: {
      icon: 'issue-type-issue',
      title: s__('DuoAgentsPlatform|List comments'),
      level: 0,
    },
    create_commit: { icon: 'commit', title: s__('DuoAgentsPlatform|Create commit'), level: 1 },
  };

  return (
    toolMap[toolName] || {
      icon: 'issue-type-maintenance',
      title: s__('DuoAgentsPlatform|Action'),
      level: 0,
    }
  );
};

export const getMessageData = (message) => {
  if (!message.message_type) {
    throw new Error(`Message requires property 'message_type' but got ${JSON.stringify(message)} `);
  }

  switch (message.message_type) {
    case 'user':
      return { icon: 'user', title: s__('DuoAgentPlatform|User messaged agent'), level: 1 };
    case 'request':
      return {
        icon: 'question-o',
        title: s__('DuoAgentPlatform|Agent required human input'),
        level: 1,
      };
    case 'agent':
      return { icon: 'tanuki-ai', title: s__('DuoAgentPlatform|Agent reasoning'), level: 0 };
    case 'tool':
      return getToolData(message);
    default:
      return { icon: 'issue-type-maintenance', title: s__('DuoAgentPlatform|Action'), level: 0 };
  }
};
