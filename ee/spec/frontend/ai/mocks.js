export const mockAgentFlowEdges = [
  {
    node: {
      __typename: 'DuoWorkflow',
      id: 'gid://gitlab/DuoWorkflow::Workflow/1',
      status: 'FINISHED',
      humanStatus: 'completed',
      updatedAt: '2024-01-01T00:00:00Z',
      workflowDefinition: 'software_development',
      project: {
        id: 'gid://gitlab/Project/1',
        name: 'Test Project',
        webUrl: 'https://gitlab.com/gitlab-org/test-project',
        namespace: {
          id: 'gid://gitlab/Group/1',
          name: 'gitlab-org',
          webUrl: 'https://gitlab.com/gitlab-org',
        },
      },
    },
  },
  {
    node: {
      __typename: 'DuoWorkflow',
      id: 'gid://gitlab/DuoWorkflow::Workflow/2',
      status: 'RUNNING',
      humanStatus: 'running',
      updatedAt: '2024-01-02T00:00:00Z',
      workflowDefinition: 'convert_to_gitlab_ci',
      project: {
        id: 'gid://gitlab/Project/2',
        name: 'Another Project',
        webUrl: 'https://gitlab.com/gitlab-org/another-project',
        namespace: {
          id: 'gid://gitlab/Group/1',
          name: 'gitlab-org',
          webUrl: 'https://gitlab.com/gitlab-org',
        },
      },
    },
  },
  {
    node: {
      __typename: 'DuoWorkflow',
      id: 'gid://gitlab/DuoWorkflow::Workflow/3',
      status: 'CREATED',
      humanStatus: 'created',
      updatedAt: '2024-01-03T00:00:00Z',
      workflowDefinition: 'chat',
      project: {
        id: 'gid://gitlab/Project/3',
        name: 'Chat Project',
        webUrl: 'https://gitlab.com/test-group/chat-project',
        namespace: {
          id: 'gid://gitlab/Group/2',
          name: 'test-group',
          webUrl: 'https://gitlab.com/test-group',
        },
      },
    },
  },
];

export const mockAgentFlows = mockAgentFlowEdges.map((edge) => edge.node);

export const mockAgentFlowsResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      duoWorkflowWorkflows: {
        pageInfo: {
          startCursor: 'start',
          endCursor: 'end',
          hasNextPage: true,
          hasPreviousPage: false,
        },
        edges: mockAgentFlowEdges,
      },
    },
  },
};

export const mockAgentFlowsResponseEmpty = {
  data: {
    duoWorkflowWorkflows: [],
  },
};

export const mockAgentFlowCheckpoint =
  '{"v":2,"id":"1f058111-196c-6f6a-800b-62ef2159a3c7","ts":"2025-07-03T13:24:38.126956+00:00","pending_sends":[],"versions_seen":{"__input__":{},"__start__":{"__start__":1},"build_context":{"start:build_context":3,"branch:to:build_context":12},"build_context_tools":{"branch:to:build_context_tools":11}},"channel_values":{"plan":{"steps":[]},"status":"Not Started","handover":[],"ui_chat_log":[{"status":"success","content":"Starting workflow with goal: Hello world i nJS","timestamp":"2025-07-03T13:24:14.467716+00:00","tool_info":null,"message_type":"tool","correlation_id":null,"context_elements":null,"message_sub_type":null,"additional_context":null},{"status":"success","content":"I\'ll help you explore the GitLab project to understand the context for \\"Hello world in JS\\". Let me start by checking the current working directory and gathering information about the project structure.","timestamp":"2025-07-03T13:24:18.019182+00:00","tool_info":null,"message_type":"agent","correlation_id":null,"context_elements":null,"message_sub_type":null,"additional_context":null},{"status":"success","content":"Using list_dir: directory=.","timestamp":"2025-07-03T13:24:18.088379+00:00","tool_info":{"args":{"directory":"."},"name":"list_dir"},"message_type":"tool","correlation_id":null,"context_elements":null,"message_sub_type":"list_dir","additional_context":null},{"status":"success","content":"Let me try to get more information about the project structure:","timestamp":"2025-07-03T13:24:21.174084+00:00","tool_info":null,"message_type":"agent","correlation_id":null,"context_elements":null,"message_sub_type":null,"additional_context":null},{"status":"success","content":"Search files with pattern \'*.js\'","timestamp":"2025-07-03T13:24:21.245706+00:00","tool_info":{"args":{"name_pattern":"*.js"},"name":"find_files"},"message_type":"tool","correlation_id":null,"context_elements":null,"message_sub_type":"find_files","additional_context":null},{"status":"success","content":"Search files with pattern \'*.json\'","timestamp":"2025-07-03T13:24:25.532768+00:00","tool_info":{"args":{"name_pattern":"*.json"},"name":"find_files"},"message_type":"tool","correlation_id":null,"context_elements":null,"message_sub_type":"find_files","additional_context":null}]}}';

export const mockGetAgentFlowResponse = {
  data: {
    duoWorkflowWorkflows: {
      edges: [
        {
          node: {
            __typename: 'DuoWorkflow',
            id: 'gid://gitlab/DuoWorkflow::Workflow/1',
            createdAt: '2023-01-01T00:00:00Z',
            status: 'RUNNING',
            updatedAt: '2024-01-01T00:00:00Z',
            latestCheckpoint: { checkpoint: mockAgentFlowCheckpoint },
            lastExecutorLogsUrl: 'https://gitlab.com/gitlab-org/gitlab/-/pipelines/123',
            errors: null,
            humanStatus: 'running',
            workflowDefinition: 'software_development',
            project: {
              id: 'gid://gitlab/Project/1',
              name: 'Test Project',
              webUrl: 'https://gitlab.com/gitlab-org/test-project',
              namespace: {
                id: 'gid://gitlab/Group/1',
                name: 'gitlab-org',
                webUrl: 'https://gitlab.com/gitlab-org',
              },
            },
          },
        },
      ],
    },
  },
};

export const mockCreateFlowResponse = {
  id: 1056241,
  project_id: 46519181,
  namespace_id: null,
  agent_privileges: [1, 2, 3, 4, 5],
  agent_privileges_names: [
    'read_write_files',
    'read_only_gitlab',
    'read_write_gitlab',
    'run_commands',
    'use_git',
  ],
  pre_approved_agent_privileges: [1, 2],
  pre_approved_agent_privileges_names: ['read_write_files', 'read_only_gitlab'],
  workflow_definition: 'issue_to_merge_request',
  status: 'created',
  allow_agent_to_request_user: true,
  image: null,
  environment: 'web',
  workload: {
    id: 1000338,
    message: null,
  },
  mcp_enabled: true,
  gitlab_url: 'https://gitlab.com',
};
