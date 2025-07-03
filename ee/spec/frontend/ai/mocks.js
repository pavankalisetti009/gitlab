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

export const mockRealCheckpoint =
  '{"v":2,"id":"1f058111-196c-6f6a-800b-62ef2159a3c7","ts":"2025-07-03T13:24:38.126956+00:00","pending_sends":[],"versions_seen":{"__input__":{},"__start__":{"__start__":1},"build_context":{"start:build_context":3,"branch:to:build_context":12},"build_context_tools":{"branch:to:build_context_tools":11}},"channel_values":{"plan":{"steps":[]},"status":"Not Started","handover":[],"ui_chat_log":[{"status":"success","content":"Starting workflow with goal: Hello world i nJS","timestamp":"2025-07-03T13:24:14.467716+00:00","tool_info":null,"message_type":"tool","correlation_id":null,"context_elements":null,"message_sub_type":null,"additional_context":null},{"status":"success","content":"I\'ll help you explore the GitLab project to understand the context for \\"Hello world in JS\\". Let me start by checking the current working directory and gathering information about the project structure.","timestamp":"2025-07-03T13:24:18.019182+00:00","tool_info":null,"message_type":"agent","correlation_id":null,"context_elements":null,"message_sub_type":null,"additional_context":null},{"status":"success","content":"Using list_dir: directory=.","timestamp":"2025-07-03T13:24:18.088379+00:00","tool_info":{"args":{"directory":"."},"name":"list_dir"},"message_type":"tool","correlation_id":null,"context_elements":null,"message_sub_type":"list_dir","additional_context":null},{"status":"success","content":"Let me try to get more information about the project structure:","timestamp":"2025-07-03T13:24:21.174084+00:00","tool_info":null,"message_type":"agent","correlation_id":null,"context_elements":null,"message_sub_type":null,"additional_context":null},{"status":"success","content":"Search files with pattern \'*.js\'","timestamp":"2025-07-03T13:24:21.245706+00:00","tool_info":{"args":{"name_pattern":"*.js"},"name":"find_files"},"message_type":"tool","correlation_id":null,"context_elements":null,"message_sub_type":"find_files","additional_context":null},{"status":"success","content":"Search files with pattern \'*.json\'","timestamp":"2025-07-03T13:24:25.532768+00:00","tool_info":{"args":{"name_pattern":"*.json"},"name":"find_files"},"message_type":"tool","correlation_id":null,"context_elements":null,"message_sub_type":"find_files","additional_context":null}]}}';

export const mockWorkflowEvents = [
  {
    checkpoint: mockRealCheckpoint,
  },
  {
    checkpoint: checkpoint2,
  },
  {
    checkpoint: checkpoint1,
  },
];
