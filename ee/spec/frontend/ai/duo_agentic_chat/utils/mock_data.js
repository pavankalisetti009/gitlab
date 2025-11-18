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
