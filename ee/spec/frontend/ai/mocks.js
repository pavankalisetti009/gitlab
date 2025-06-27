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
