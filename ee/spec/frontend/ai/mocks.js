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

export const mockDuoMessages = [
  {
    status: 'success',
    content: 'Starting workflow with goal: Hello world in JS',
    timestamp: '2025-07-03T13:24:14.467716+00:00',
    toolInfo: null,
    messageType: 'tool',
    correlationId: null,
    role: null,
  },
  {
    status: 'success',
    content:
      'I\'ll help you explore the GitLab project to understand the context for "Hello world in JS". Let me start by checking the current working directory and gathering information about the project structure.',
    timestamp: '2025-07-03T13:24:18.019182+00:00',
    toolInfo: null,
    messageType: 'agent',
    correlationId: null,
    role: null,
  },
];

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
            lastExecutorLogsUrl: 'https://gitlab.com/gitlab-org/gitlab/-/jobs/456',
            latestCheckpoint: { duoMessages: mockDuoMessages },
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
