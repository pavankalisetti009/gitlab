// Mock data for transformChatMessages tests
export const MOCK_AGENT_MESSAGE = { message_type: 'agent', content: 'Agent message' };
export const MOCK_REQUEST_MESSAGE = { message_type: 'request', content: 'Request message' };
export const MOCK_USER_MESSAGE = { message_type: 'user', content: 'User message' };
export const MOCK_GENERIC_MESSAGE = { message_type: 'generic', content: 'Generic message' };
export const MOCK_PROJECT_ID = 'gid://gitlab/Project/123';
export const MOCK_NAMESPACE_ID = 'gid://gitlab/Group/456';
export const MOCK_WORKFLOW_ID = 'gid://gitlab/Ai::DuoWorkflow/789';
export const MOCK_THREAD_ID = 'thread-123';
export const MOCK_GOAL = 'Optimize CI pipeline';
export const MOCK_ACTIVE_THREAD = 'active-thread-456';

export const MOCK_WORKFLOW_MUTATION_RESPONSE = {
  data: {
    aiDuoWorkflowCreate: {
      workflow: {
        id: MOCK_WORKFLOW_ID,
        threadId: MOCK_THREAD_ID,
      },
      errors: [],
    },
  },
};

export const MOCK_DELETE_WORKFLOW_RESPONSE = {
  data: {
    deleteDuoWorkflowsWorkflow: {
      success: true,
      clientMutationId: null,
      errors: [],
    },
  },
};

export const MOCK_FETCH_WORKFLOW_EVENTS_RESPONSE = {
  data: {
    duoWorkflowEvents: {
      nodes: [
        {
          id: 'event-1',
          checkpoint: '{"test": "data"}',
        },
      ],
    },
  },
};

export const MOCK_ASSISTANT_MESSAGES = [MOCK_AGENT_MESSAGE, MOCK_REQUEST_MESSAGE];
export const MOCK_SINGLE_GENERIC_MESSAGE = [MOCK_GENERIC_MESSAGE];
export const MOCK_MULTIPLE_USER_MESSAGES = [
  { message_type: 'user', content: 'First' },
  { message_type: 'user', content: 'Second' },
  { message_type: 'user', content: 'Third' },
];
export const MOCK_USER_MESSAGE_WITH_PROPERTIES = [
  {
    message_type: 'user',
    content: 'Test message',
    timestamp: '2025-07-25T14:30:00Z',
    customProperty: 'should be preserved',
    metadata: { key: 'value' },
  },
];

export const MOCK_WORKFLOW_EVENTS_MULTIPLE = [
  {
    checkpoint: {
      ts: '2025-07-25T14:30:10.117131+00:00',
    },
    metadata: 'first',
    errors: [],
    workflowStatus: 'RUNNING',
    workflowGoal: 'Test goal 1',
  },
  {
    checkpoint: {
      ts: '2025-07-25T14:30:43.905127+00:00', // Most recent
    },
    metadata: 'second',
    errors: [],
    workflowStatus: 'INPUT_REQUIRED',
    workflowGoal: 'Test goal 2',
  },
  {
    checkpoint: {
      ts: '2025-07-25T14:30:05.420790+00:00',
    },
    metadata: 'third',
    errors: [],
    workflowStatus: 'EXECUTION',
    workflowGoal: 'Test goal 3',
  },
];

export const MOCK_SINGLE_WORKFLOW_EVENT = [
  {
    checkpoint: {
      ts: '2025-07-25T14:30:10.117131+00:00',
    },
    metadata: 'single event',
    errors: ['some error'],
    workflowStatus: 'FAILED',
    workflowGoal: 'Single goal',
  },
];

export const MOCK_PARSE_WORKFLOW_RESPONSE = {
  duoWorkflowEvents: {
    nodes: [
      {
        metadata: 'first',
        checkpoint: '{"ts": "2025-07-25T14:30:10.117131+00:00", "data": "test1"}',
      },
      {
        metadata: 'second',
        checkpoint: '{"ts": "2025-07-25T14:30:43.905127+00:00", "data": "test2"}',
      },
    ],
  },
};

export const MOCK_PARSE_WORKFLOW_EMPTY_RESPONSE = {
  duoWorkflowEvents: {
    nodes: [],
  },
};

export const MOCK_PARSE_WORKFLOW_PRESERVE_PROPERTIES_RESPONSE = {
  duoWorkflowEvents: {
    nodes: [
      {
        metadata: 'test',
        workflowStatus: 'RUNNING',
        customProperty: 'preserved',
        checkpoint: '{"ts": "2025-07-25T14:30:10.117131+00:00"}',
      },
    ],
  },
};

export const MOCK_AGENT_FLOW_CONFIG_RESPONSE = {
  data: {
    aiCatalogAgentFlowConfig: {
      flowConfig: 'YAML STRING',
    },
  },
};

export const MOCK_CONFIGURED_AGENTS_RESPONSE = {
  data: {
    aiCatalogConfiguredItems: {
      nodes: [
        {
          id: 'Configured Item 5',
          item: {
            id: 'Agent 5',
            name: 'My Custom Agent',
            description: 'This is my custom agent',
            versions: {
              nodes: [
                {
                  id: 'AgentVersion 6',
                  released: false,
                },
                {
                  id: 'AgentVersion 5',
                  released: true,
                },
              ],
            },
          },
        },
      ],
    },
  },
};

export const MOCK_FOUNDATIONAL_CHAT_AGENTS_RESPONSE = {
  data: {
    aiFoundationalChatAgents: {
      nodes: [
        {
          id: 'gid://gitlab/Ai::FoundationalChatAgent/chat',
          name: 'GitLab Duo Agent',
          description: 'Duo is your general development assistant',
          referenceWithVersion: 'chat',
        },
        {
          id: 'gid://gitlab/Ai::FoundationalChatAgent/agent-v1',
          name: 'Cool agent',
          description: 'An agent that makes things cooler',
          referenceWithVersion: 'agent/v1',
        },
      ],
    },
  },
};

export const MOCK_CHAT_MESSAGES = {
  prompt: {
    content: 'Update the README to explain the main languages used in the project',
    role: 'user',
  },
  user: {
    message_sub_type: null,
    message_type: 'user',
    content: 'Update the README to explain the main languages used in the project',
    timestamp: '2025-11-18T09:52:38.523380+00:00',
    status: 'success',
    correlation_id: null,
    tool_info: null,
    additional_context: [
      {
        category: 'repository',
        id: '',
        content:
          '<current_gitlab_page_url>gdk.test:8080/gitlab-duo/test</current_gitlab_page_url>\n<current_gitlab_page_title>GitLab Duo / Test · GitLab</current_gitlab_page_title>',
        metadata: {},
        type: 'AdditionalContext',
      },
    ],
    role: 'user',
  },
  agentStreaming: {
    status: null,
    correlation_id: null,
    message_type: 'agent',
    message_sub_type: null,
    timestamp: '2025-11-18T09:52:43.756171+00:00',
    content: "I'll update",
    tool_info: null,
    additional_context: null,
    role: 'assistant',
  },
  agentStreaming1: {
    status: null,
    correlation_id: null,
    message_type: 'agent',
    message_sub_type: null,
    timestamp: '2025-11-18T09:52:43.756171+00:00',
    content: "I'll update the README to explain the main languages",
    tool_info: null,
    additional_context: null,
    role: 'assistant',
  },
  agentComplete: {
    message_type: 'agent',
    message_sub_type: null,
    content:
      "I'll update the README to explain the main languages used in the project. First, let me get the current README content.",
    timestamp: '2025-11-18T09:52:45.082275+00:00',
    status: 'success',
    correlation_id: null,
    tool_info: null,
    additional_context: null,
    role: 'assistant',
  },
  tool: {
    message_type: 'tool',
    message_sub_type: 'get_repository_file',
    content: 'Get repository file README.md from project 1000000 at ref HEAD',
    timestamp: '2025-11-18T09:52:45.530655+00:00',
    status: 'success',
    correlation_id: null,
    tool_info: {
      name: 'get_repository_file',
      args: {
        project_id: 1000000,
        file_path: 'README.md',
        ref: 'HEAD',
      },
      tool_response: {
        content:
          '# Test project for GitLab Duo\\n\\nThis project is for testing GitLab Duo. Seeded by #seed-project-and-group-resources-for-testing-and-evaluation.',
        additional_kwargs: {},
        response_metadata: {},
        type: 'ToolMessage',
        name: 'get_repository_file',
        id: null,
        tool_call_id: 'toolu_vrtx_016EoHinnPT6nxKTHookKNDL',
        artifact: null,
        status: 'success',
      },
    },
    additional_context: null,
    role: 'tool',
  },
  agent2Streaming1: {
    status: null,
    correlation_id: null,
    message_type: 'agent',
    message_sub_type: null,
    timestamp: '2025-11-18T09:52:47.922360+00:00',
    content: 'Now',
    tool_info: null,
    additional_context: null,
    role: 'assistant',
  },
  agent2Streaming2: {
    status: null,
    correlation_id: null,
    message_type: 'agent',
    message_sub_type: null,
    timestamp: '2025-11-18T09:52:47.922360+00:00',
    content: "Now I'll update the README to",
    tool_info: null,
    additional_context: null,
    role: 'assistant',
  },
  request: {
    status: 'success',
    content: 'Tool create_commit requires approval. Please confirm if you want to proceed.',
    timestamp: '2025-11-18T09:52:54.430519+00:00',
    tool_info: {
      args: {
        actions: [
          {
            action: 'update',
            new_str:
              '# Test project for GitLab Duo\n\nThis project is for testing GitLab Duo. Seeded by #seed-project-and-group-resources-for-testing-and-evaluation.\n\n',
            old_str:
              '# Test project for GitLab Duo\n\nThis project is for testing GitLab Duo. Seeded by #seed-project-and-group-resources-for-testing-and-evaluation.',
            file_path: 'README.md',
          },
        ],
        project_id: 1000000,
        commit_message: 'Update README to explain main languages used in the project',
      },
      name: 'create_commit',
    },
    message_type: 'request',
    correlation_id: null,
    message_sub_type: null,
    additional_context: null,
    role: 'assistant',
  },
  tool3Fail: [
    {
      message_type: 'tool',
      message_sub_type: 'create_commit',
      content:
        'Failed: Create commit in project 1000000 on new auto-created branch with 1 file action (update) - Tool call failed: ToolException',
      timestamp: '2025-11-18T10:34:57.625572+00:00',
      status: 'failure',
      correlation_id: null,
      tool_info: {
        name: 'create_commit',
        args: {
          actions: [
            {
              action: 'update',
              content: '# Test project for GitLab Duo\n\nThis project is for testing GitLab Duo.',
              file_path: 'README.md',
            },
          ],
          project_id: 1000000,
          commit_message: 'Update README to explain main languages used in the project',
        },
      },
      additional_context: null,
      role: 'tool',
    },
    {
      status: null,
      correlation_id: null,
      message_type: 'agent',
      message_sub_type: null,
      timestamp: '2025-11-14T10:15:45.971730+00:00',
      content: 'Let me try with the full content approach:',
      tool_info: null,
      additional_context: null,
      role: 'assistant',
    },
  ],
};
