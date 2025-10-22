const TYPENAME_AI_CATALOG_ITEM = 'AiCatalogItem';
const TYPENAME_AI_CATALOG_ITEM_CONNECTION = 'AiCatalogItemConnection';
const TYPENAME_AI_CATALOG_ITEM_CONSUMER = 'AiCatalogItemConsumer';
const TYPENAME_AI_CATALOG_ITEM_CONSUMER_DELETE = 'AiCatalogItemConsumerDeletePayload';
const TYPENAME_AI_CATALOG_ITEM_CONSUMER_CONNECTION = 'AiCatalogItemConsumerConnection';
const TYPENAME_AI_CATALOG_AGENT_CREATE = 'AiCatalogAgentCreatePayload';
const TYPENAME_AI_CATALOG_AGENT_UPDATE = 'AiCatalogAgentUpdatePayload';
const TYPENAME_AI_CATALOG_AGENT_DELETE = 'AiCatalogAgentDeletePayload';
const TYPENAME_AI_CATALOG_AGENT_VERSION = 'AiCatalogAgentVersion';
const TYPENAME_AI_CATALOG_AGENT_TOOLS_CONNECTION = 'AiCatalogBuiltInToolConnection';
const TYPENAME_AI_CATALOG_FLOW_VERSION = 'AiCatalogFlowVersion';
const TYPENAME_AI_CATALOG_FLOW_CREATE = 'AiCatalogFlowCreatePayload';
const TYPENAME_AI_CATALOG_FLOW_UPDATE = 'AiCatalogFlowUpdatePayload';
const TYPENAME_AI_CATALOG_FLOW_DELETE = 'AiCatalogFlowDeletePayload';
const TYPENAME_AI_CATALOG_THIRD_PARTY_FLOW_VERSION = 'AiCatalogThirdPartyFlowVersion';
const TYPENAME_PROJECT = 'Project';
const TYPENAME_PROJECT_PERMISSIONS = 'ProjectPermissions';
const TYPENAME_PROJECTS_CONNECTION = 'ProjectsConnection';

export const mockBaseLatestVersion = {
  id: 'gid://gitlab/Ai::Catalog::ItemVersion/1',
  updatedAt: '2025-08-21T14:30:00Z',
};

const mockProjectFactory = (overrides = {}) => ({
  id: 'gid://gitlab/Project/1',
  __typename: TYPENAME_PROJECT,
  ...overrides,
});

const mockProjectWithNamespace = mockProjectFactory({
  nameWithNamespace: 'Group / Project 1',
});

export const mockPageInfo = {
  hasNextPage: true,
  hasPreviousPage: false,
  startCursor: 'eyJpZCI6IjUxIn0',
  endCursor: 'eyJpZCI6IjM1In0',
  __typename: 'PageInfo',
};

export const mockProjects = [
  mockProjectFactory({
    id: 'gid://gitlab/Project/1',
    name: 'Project 1',
    nameWithNamespace: 'Group / Project 1',
  }),
  mockProjectFactory({
    id: 'gid://gitlab/Project/2',
    name: 'Project 2',
    nameWithNamespace: 'Group / Project 2',
  }),
];

export const mockProjectsResponse = {
  data: {
    projects: {
      nodes: mockProjects,
      pageInfo: mockPageInfo,
      __typename: TYPENAME_PROJECTS_CONNECTION,
    },
  },
};

export const mockEmptyProjectsResponse = {
  data: {
    projects: {
      nodes: [],
      pageInfo: {
        hasNextPage: false,
        hasPreviousPage: false,
        startCursor: null,
        endCursor: null,
      },
      __typename: TYPENAME_PROJECTS_CONNECTION,
    },
  },
};

export const mockToolsIds = [
  'gid://gitlab/Ai::Catalog::BuiltInTool/1',
  'gid://gitlab/Ai::Catalog::BuiltInTool/2',
  'gid://gitlab/Ai::Catalog::BuiltInTool/3',
];
export const mockToolsTitles = ['Run Git Command', 'Gitlab Blob Search', 'Ci Linter'];

const aiCatalogBuiltInToolsNodes = [
  {
    id: `gid://gitlab/Ai::Catalog::BuiltInTool/3`,
    title: 'Ci Linter',
  },
  {
    id: `gid://gitlab/Ai::Catalog::BuiltInTool/2`,
    title: 'Gitlab Blob Search',
  },
  {
    id: `gid://gitlab/Ai::Catalog::BuiltInTool/1`,
    title: 'Run Git Command',
  },
];

export const mockToolsQueryResponse = {
  data: {
    aiCatalogBuiltInTools: {
      nodes: aiCatalogBuiltInToolsNodes,
      __typename: TYPENAME_AI_CATALOG_AGENT_TOOLS_CONNECTION,
    },
  },
};

/* AGENTS */

export const mockAgentVersions = {
  nodes: [
    {
      id: 'gid://gitlab/Ai::Catalog::ItemVersion/20',
      systemPrompt: 'sys',
      tools: { nodes: [], __typename: TYPENAME_AI_CATALOG_AGENT_TOOLS_CONNECTION },
      versionName: '1.0.0',
      humanVersionName: 'v1.0.0',
      __typename: TYPENAME_AI_CATALOG_AGENT_VERSION,
    },
  ],
  __typename: 'AiCatalogItemVersionConnection',
};

const mockAgentFactory = (overrides = {}) => ({
  id: 'gid://gitlab/Ai::Catalog::Item/1',
  name: 'Test AI Agent 1',
  itemType: 'AGENT',
  description: 'A helpful AI assistant for testing purposes',
  createdAt: '2024-01-15T10:30:00Z',
  public: true,
  updatedAt: '2024-08-21T14:30:00Z',
  latestVersion: mockBaseLatestVersion,
  userPermissions: {
    adminAiCatalogItem: true,
  },
  __typename: TYPENAME_AI_CATALOG_ITEM,
  ...overrides,
});

export const mockAgentVersion = {
  ...mockBaseLatestVersion,
  humanVersionName: 'v1.0.0-draft',
  versionName: '1.0.0',
  __typename: TYPENAME_AI_CATALOG_AGENT_VERSION,
  systemPrompt: 'The system prompt',
  tools: {
    nodes: [],
    __typename: TYPENAME_AI_CATALOG_AGENT_TOOLS_CONNECTION,
  },
};

export const mockBaseAgent = mockAgentFactory();

export const mockAgent = mockAgentFactory({
  project: mockProjectWithNamespace,
  latestVersion: mockAgentVersion,
  versions: mockAgentVersions,
});

export const mockAgents = [
  mockAgentFactory({
    project: mockProjectWithNamespace,
    versions: mockAgentVersions,
  }),
  mockAgentFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/2',
    name: 'Test AI Agent 2',
    description: 'Another AI assistant',
    createdAt: '2024-02-10T14:20:00Z',
    project: mockProjectWithNamespace,
    versions: mockAgentVersions,
  }),
  mockAgentFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/3',
    name: 'Test AI Agent 3',
    description: 'Another AI assistant',
    createdAt: '2024-02-10T14:20:00Z',
    project: mockProjectWithNamespace,
    versions: mockAgentVersions,
    public: false,
  }),
];

export const mockCatalogItemsResponse = {
  data: {
    aiCatalogItems: {
      nodes: mockAgents,
      pageInfo: mockPageInfo,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONNECTION,
    },
  },
};

export const mockCatalogEmptyItemsResponse = {
  data: {
    aiCatalogItems: {
      nodes: [],
      pageInfo: mockPageInfo,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONNECTION,
    },
  },
};

export const mockAiCatalogAgentResponse = {
  data: {
    aiCatalogItem: mockAgent,
  },
};

export const mockAiCatalogAgentNullResponse = {
  data: {
    aiCatalogItem: null,
  },
};

export const mockCatalogAgentDeleteResponse = {
  data: {
    aiCatalogAgentDelete: {
      errors: [],
      success: true,
      __typename: TYPENAME_AI_CATALOG_AGENT_DELETE,
    },
  },
};

export const mockCatalogAgentDeleteErrorResponse = {
  data: {
    aiCatalogAgentDelete: {
      errors: ['You do not have permission to delete this AI agent.'],
      success: false,
      __typename: TYPENAME_AI_CATALOG_AGENT_DELETE,
    },
  },
};

export const mockCreateAiCatalogAgentSuccessMutation = {
  data: {
    aiCatalogAgentCreate: {
      errors: [],
      item: mockBaseAgent,
      __typename: TYPENAME_AI_CATALOG_AGENT_CREATE,
    },
  },
};

export const mockCreateAiCatalogAgentSuccessWithEnableFailureMutation = {
  data: {
    aiCatalogAgentCreate: {
      errors: ['Could not enable'],
      item: mockBaseAgent,
      __typename: TYPENAME_AI_CATALOG_AGENT_CREATE,
    },
  },
};

export const mockCreateAiCatalogAgentErrorMutation = {
  data: {
    aiCatalogAgentCreate: {
      errors: ['Some error'],
      item: null,
    },
  },
};

export const mockUpdateAiCatalogAgentSuccessMutation = {
  data: {
    aiCatalogAgentUpdate: {
      errors: [],
      item: mockAgent,
      __typename: TYPENAME_AI_CATALOG_AGENT_UPDATE,
    },
  },
};

export const mockUpdateAiCatalogAgentErrorMutation = {
  data: {
    aiCatalogAgentUpdate: {
      errors: ['Some error'],
      item: null,
    },
  },
};

export const mockExecuteAgentSuccessResponse = {
  data: {
    aiCatalogAgentExecute: {
      errors: [],
      workflow: {
        id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/1',
        project: mockProjectFactory({ fullPath: 'gitlab-duo/test' }),
      },
      __typename: 'AiCatalogAgentExecutePayload',
    },
  },
};

export const mockExecuteAgentErrorResponse = {
  data: {
    aiCatalogAgentExecute: {
      errors: ['Could not find agent ID'],
      workflow: null,
      __typename: 'AiCatalogAgentExecutePayload',
    },
  },
};

/* FLOWS */

export const mockFlowVersion = {
  ...mockBaseLatestVersion,
  humanVersionName: 'v1.0.0-draft',
  versionName: '1.0.0',
  steps: {
    nodes: [
      {
        pinnedVersionPrefix: '1.0.0',
        agent: {
          id: 'gid://gitlab/Ai::Catalog::ItemVersion/100',
          name: 'Agent',
          versions: mockAgentVersions,
          __typename: 'AiCatalogAgent',
        },
        __typename: 'AiCatalogFlowSteps',
      },
    ],
    __typename: 'AiCatalogFlowStepsConnection',
  },
  __typename: TYPENAME_AI_CATALOG_FLOW_VERSION,
};

const mockFlowFactory = (overrides = {}) => ({
  id: 'gid://gitlab/Ai::Catalog::Item/4',
  name: 'Test AI Flow 1',
  itemType: 'FLOW',
  description: 'A helpful AI flow for testing purposes',
  createdAt: '2024-01-15T10:30:00Z',
  public: true,
  updatedAt: '2024-08-21T14:30:00Z',
  latestVersion: mockBaseLatestVersion,
  userPermissions: {
    adminAiCatalogItem: true,
  },
  __typename: TYPENAME_AI_CATALOG_ITEM,
  ...overrides,
});

export const mockFlow = mockFlowFactory({
  project: mockProjectWithNamespace,
  latestVersion: mockFlowVersion,
});

export const mockBaseFlow = mockFlowFactory();

export const mockFlows = [
  mockFlowFactory({
    project: mockProjectWithNamespace,
  }),
  mockFlowFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/5',
    name: 'Test AI Flow 2',
    description: 'Another AI flow',
    createdAt: '2024-02-10T14:20:00Z',
    project: mockProjectWithNamespace,
  }),
  mockFlowFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/6',
    name: 'Test AI Flow 3',
    description: 'Another AI flow',
    createdAt: '2024-02-10T14:20:00Z',
    project: mockProjectWithNamespace,
  }),
];

export const mockCatalogFlowsResponse = {
  data: {
    aiCatalogItems: {
      nodes: mockFlows,
      pageInfo: mockPageInfo,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONNECTION,
    },
  },
};

export const mockCreateAiCatalogFlowSuccessMutation = {
  data: {
    aiCatalogFlowCreate: {
      errors: [],
      item: mockFlow,
      __typename: TYPENAME_AI_CATALOG_FLOW_CREATE,
    },
  },
};

export const mockCreateAiCatalogFlowSuccessWithEnableFailureMutation = {
  data: {
    aiCatalogFlowCreate: {
      errors: ['Could not enable'],
      item: mockFlow,
      __typename: TYPENAME_AI_CATALOG_FLOW_CREATE,
    },
  },
};

export const mockCreateAiCatalogFlowErrorMutation = {
  data: {
    aiCatalogFlowCreate: {
      errors: ['Some error'],
      item: null,
    },
  },
};

export const mockUpdateAiCatalogFlowSuccessMutation = {
  data: {
    aiCatalogFlowUpdate: {
      errors: [],
      item: mockFlow,
      __typename: TYPENAME_AI_CATALOG_FLOW_UPDATE,
    },
  },
};

export const mockUpdateAiCatalogFlowErrorMutation = {
  data: {
    aiCatalogFlowUpdate: {
      errors: ['Some error'],
      item: null,
    },
  },
};

export const mockAiCatalogFlowResponse = {
  data: {
    aiCatalogItem: mockFlow,
  },
};

export const mockAiCatalogFlowNullResponse = {
  data: {
    aiCatalogItem: null,
  },
};

export const mockCatalogFlowDeleteResponse = {
  data: {
    aiCatalogFlowDelete: {
      errors: [],
      success: true,
      __typename: TYPENAME_AI_CATALOG_FLOW_DELETE,
    },
  },
};

export const mockCatalogFlowDeleteErrorResponse = {
  data: {
    aiCatalogFlowDelete: {
      errors: ['You do not have permission to delete this AI flow.'],
      success: false,
      __typename: TYPENAME_AI_CATALOG_FLOW_DELETE,
    },
  },
};

/* THIRD-PARTY FLOWS */

export const mockThirdPartyFlowVersion = {
  ...mockBaseLatestVersion,
  humanVersionName: 'v1.0.0-draft',
  versionName: '1.0.0',
  definition: '---\\nimage: node:22\\ncommands:\\n- ls\\ninjectGatewayToken: true\\n',
  __typename: TYPENAME_AI_CATALOG_THIRD_PARTY_FLOW_VERSION,
};

const mockThirdPartyFlowFactory = (overrides = {}) => ({
  ...mockFlowFactory(overrides),
  itemType: 'THIRD_PARTY_FLOW',
});

export const mockThirdPartyFlow = mockThirdPartyFlowFactory({
  project: mockProjectWithNamespace,
  latestVersion: mockThirdPartyFlowVersion,
});

/* ITEM CONSUMERS */

export const mockBaseItemConsumer = {
  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
  pinnedVersionPrefix: '0.0.1',
  __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
};

export const mockConfiguredAgentsResponse = {
  data: {
    aiCatalogConfiguredItems: {
      nodes: [
        {
          ...mockBaseItemConsumer,
          item: mockBaseAgent,
        },
      ],
      pageInfo: mockPageInfo,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER_CONNECTION,
    },
  },
};

export const mockConfiguredFlowsResponse = {
  data: {
    aiCatalogConfiguredItems: {
      nodes: [
        {
          ...mockBaseItemConsumer,
          item: mockBaseFlow,
        },
      ],
      pageInfo: mockPageInfo,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER_CONNECTION,
    },
  },
};

export const mockConfiguredItemsEmptyResponse = {
  data: {
    aiCatalogConfiguredItems: {
      nodes: [],
      pageInfo: {
        hasNextPage: false,
        hasPreviousPage: false,
        startCursor: null,
        endCursor: null,
      },
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER_CONNECTION,
    },
  },
};

export const mockAiCatalogItemConsumerCreateSuccessProjectResponse = {
  data: {
    aiCatalogItemConsumerCreate: {
      errors: [],
      itemConsumer: {
        id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
        project: {
          id: 'gid://gitlab/Project/1',
          name: 'Test',
        },
      },
    },
  },
};

export const mockAiCatalogItemConsumerCreateErrorResponse = {
  data: {
    aiCatalogItemConsumerCreate: {
      errors: ['Item already configured.'],
      itemConsumer: null,
    },
  },
};

export const mockAiCatalogItemConsumerDeleteResponse = {
  data: {
    aiCatalogItemConsumerDelete: {
      errors: [],
      success: true,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER_DELETE,
    },
  },
};

export const mockAiCatalogItemConsumerDeleteErrorResponse = {
  data: {
    aiCatalogItemConsumerDelete: {
      errors: ['You do not have permission to delete this item.'],
      success: false,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER_DELETE,
    },
  },
};

export const mockUserPermissionsResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1000000',
      userPermissions: {
        adminAiCatalogItemConsumer: true,
        adminAiCatalogItem: true,
        __typename: TYPENAME_PROJECT_PERMISSIONS,
      },
      __typename: TYPENAME_PROJECT,
    },
  },
};
