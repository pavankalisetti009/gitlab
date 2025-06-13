export const mockWorkflowEdges = [
  {
    node: {
      id: 'gid://gitlab/DuoWorkflow::Workflow/1',
      humanStatus: 'completed',
      updatedAt: '2024-01-01T00:00:00Z',
      goal: 'Test workflow 1',
    },
  },
  {
    node: {
      id: 'gid://gitlab/DuoWorkflow::Workflow/2',
      humanStatus: 'running',
      updatedAt: '2024-01-02T00:00:00Z',
      goal: 'Test workflow 2',
    },
  },
];

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
