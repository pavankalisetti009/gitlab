export const mockFlowTriggerFactory = (overrides = {}) => ({
  id: 'gid://gitlab/Ai::FlowTrigger/1',
  description: 'Test trigger',
  eventTypes: [0, 1],
  configPath: '/config/test.yml',
  configUrl: 'https://example.com/config/test.yml',
  user: {
    id: 'gid://gitlab/User/1',
    username: 'testuser',
    avatarUrl: 'https://example.com/avatar.png',
    webPath: '/testuser',
    __typename: 'UserCore',
  },
  createdAt: '2025-08-08T13:37:18Z',
  updatedAt: '2025-08-08T13:37:18Z',
  __typename: 'AiFlowTriggerType',
  ...overrides,
});

export const mockAiFlowTriggersResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1000000',
      aiFlowTriggers: { nodes: [mockFlowTriggerFactory()] },
    },
  },
};

export const mockEmptyAiFlowTriggersResponse = {
  data: {
    project: { id: 'gid://gitlab/Project/1000000', aiFlowTriggers: { nodes: [] } },
  },
};
