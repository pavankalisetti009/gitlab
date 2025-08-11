import { TYPENAME_AI_FLOW_TRIGGER } from '~/graphql_shared/constants';

export const mockFlowTriggerFactory = (overrides = {}) => ({
  id: `gid://gitlab/${TYPENAME_AI_FLOW_TRIGGER}/1`,
  description: 'Test trigger',
  eventTypes: [0, 1],
  configPath: '/config/test.yml',
  configUrl: 'https://example.com/config/test.yml',
  user: {
    id: 'gid://gitlab/User/1',
    username: 'testuser',
    name: 'Test User',
    avatarUrl: 'https://example.com/avatar.png',
    webPath: '/testuser',
    webUrl: 'https://example.com/testuser',
    __typename: 'UserCore',
  },
  createdAt: '2025-08-08T13:37:18Z',
  updatedAt: '2025-08-08T13:37:18Z',
  __typename: TYPENAME_AI_FLOW_TRIGGER,
  ...overrides,
});

export const mockTrigger = mockFlowTriggerFactory();

export const mockTriggers = [mockTrigger];

export const mockTriggersWithoutUser = [mockFlowTriggerFactory({ user: undefined })];

export const mockTriggersConfigPath = [mockFlowTriggerFactory({ configPath: '', configUrl: '' })];

export const mockAiFlowTriggersResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1000000',
      aiFlowTriggers: { nodes: mockTriggers },
    },
  },
};

export const mockDeleteTriggerResponse = {
  data: {
    aiFlowTriggerDelete: {
      errors: [],
    },
  },
};

export const mockEmptyAiFlowTriggersResponse = {
  data: {
    project: { id: 'gid://gitlab/Project/1000000', aiFlowTriggers: { nodes: [] } },
  },
};

export const eventTypeOptions = [
  { value: 0, text: 'Mention' },
  { value: 1, text: 'Assign' },
];

export const mockCreateFlowTriggerSuccessMutation = {
  data: {
    aiFlowTriggerCreate: {
      aiFlowTrigger: mockTrigger,
      errors: [],
    },
  },
};

export const mockCreateFlowTriggerErrorMutation = {
  data: {
    aiFlowTriggerCreate: {
      aiFlowTrigger: null,
      errors: ['No input was provided.'],
    },
  },
};

export const mockUpdateFlowTriggerSuccessMutation = {
  data: {
    aiFlowTriggerUpdate: {
      errors: [],
    },
  },
};

export const mockUpdateFlowTriggerErrorMutation = {
  data: {
    aiFlowTriggerUpdate: {
      errors: ['No input was provided.'],
    },
  },
};
