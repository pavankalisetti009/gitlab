export const mockSelfHostedModel = {
  id: 'gid://gitlab/SelfHostedModel/1',
  name: 'mock-self-hosted-model',
  model: 'mixtral',
  endpoint: 'https://mock-endpoint.com',
  hasApiToken: false,
};

export const mockSelfHostedModelsList = [
  {
    id: 'gid://gitlab/SelfHostedModel/1',
    name: 'mock-self-hosted-model-1',
    model: 'mixtral',
    endpoint: 'https://mock-endpoint-1.com',
    hasApiToken: false,
  },
  {
    id: 'gid://gitlab/SelfHostedModel/2',
    name: 'mock-self-hosted-model-1',
    model: 'mistral',
    endpoint: 'https://mock-endpoint-2.com',
    hasApiToken: true,
  },
];

export const mockAiSelfHostedModelsQueryResponse = {
  data: {
    aiSelfHostedModels: {
      nodes: mockSelfHostedModelsList,
    },
  },
};

export const SELF_HOSTED_MODEL_OPTIONS = [
  { modelValue: 'MIXTRAL', modelName: 'Mixtral' },
  { modelValue: 'MISTRAL', modelName: 'Mistral' },
  { modelValue: 'CODEGEMMA', modelName: 'Codegemma' },
  { modelValue: 'CODESTRAL', modelName: 'Codestral' },
  { modelValue: 'CODELLAMA', modelName: 'Codellama' },
];
