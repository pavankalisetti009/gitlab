import { AGENT_MESSAGE_TYPE, TOOL_MESSAGE_TYPE } from 'ee/ai/duo_agents_platform/constants';

export const mockWorkflowEdges = [
  {
    node: {
      id: 'gid://gitlab/DuoWorkflow::Workflow/1',
      humanStatus: 'completed',
      updatedAt: '2024-01-01T00:00:00Z',
      workflowDefinition: 'software_development',
    },
  },
  {
    node: {
      id: 'gid://gitlab/DuoWorkflow::Workflow/2',
      humanStatus: 'running',
      updatedAt: '2024-01-02T00:00:00Z',
      workflowDefinition: 'convert_to_ci',
    },
  },
];

export const mockWorkflowEventsResponse = {
  data: {
    duoWorkflowEvents: {
      nodes: [
        {
          checkpoint: 'Event 1',
          errors: null,
          workflowGoal: 'Test workflow goal',
          workflowStatus: 'RUNNING',
          workflowDefinition: 'software_development',
        },
        {
          checkpoint: 'Event 2',
          errors: null,
          workflowGoal: 'Test workflow goal',
          workflowStatus: 'RUNNING',
          workflowDefinition: 'software_development',
        },
      ],
    },
  },
};

export const mockWorkflows = mockWorkflowEdges.map((edge) => edge.node);

export const mockWorkflowsResponse = {
  data: {
    duoWorkflowWorkflows: {
      pageInfo: {
        startCursor: 'start',
        endCursor: 'end',
        hasNextPage: true,
        hasPreviousPage: false,
      },
      edges: mockWorkflowEdges,
    },
  },
};

export const mockWorkflowsResponseEmpty = {
  data: {
    duoWorkflowWorkflows: [],
  },
};

export const checkpoint1 = JSON.stringify({
  channel_values: {
    ui_chat_log: [{ content: 'Starting workflow...', message_type: TOOL_MESSAGE_TYPE }],
  },
});

export const checkpoint2 = JSON.stringify({
  channel_values: {
    ui_chat_log: [
      { content: 'Starting workflow...', message_type: TOOL_MESSAGE_TYPE },
      { content: 'Processing data...', message_type: TOOL_MESSAGE_TYPE },
    ],
  },
});

export const checkpoint3 = JSON.stringify({
  channel_values: {
    ui_chat_log: [
      { content: 'Starting workflow...', message_type: TOOL_MESSAGE_TYPE },
      { content: 'Processing data...', message_type: TOOL_MESSAGE_TYPE },
      { content: 'I am done!', message_type: AGENT_MESSAGE_TYPE },
    ],
  },
});

export const mockWorkflowEvents = [
  {
    checkpoint: checkpoint1,
  },
  {
    checkpoint: checkpoint2,
  },
  {
    checkpoint: checkpoint3,
  },
];
