export const mockSelfHostedModel = {
  id: 'gid://gitlab/Ai::SelfHostedModel/1',
  name: 'mock-self-hosted-model',
  model: 'mistral',
  endpoint: 'https://mock-endpoint.com',
  identifier: 'provider/some-model-1',
  hasApiToken: true,
  featureSettings: {
    nodes: [],
  },
};

export const mockSelfHostedModelsList = [
  {
    id: 'gid://gitlab/Ai::SelfHostedModel/1',
    name: 'mock-self-hosted-model-1',
    model: 'codellama',
    endpoint: 'https://mock-endpoint-1.com',
    identifier: 'provider/some-model-1',
    hasApiToken: true,
    featureSettings: {
      nodes: [
        {
          feature: 'code_suggestions',
        },
      ],
    },
  },
  {
    id: 'gid://gitlab/Ai::SelfHostedModel/2',
    name: 'mock-self-hosted-model-2',
    model: 'mistral',
    endpoint: 'https://mock-endpoint-2.com',
    identifier: '',
    hasApiToken: true,
    featureSettings: {
      nodes: [],
    },
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
  { modelValue: 'CODEGEMMA', modelName: 'CodeGemma' },
  { modelValue: 'CODELLAMA', modelName: 'Code-Llama' },
  { modelValue: 'CODESTRAL', modelName: 'Codestral' },
  { modelValue: 'MISTRAL', modelName: 'Mistral' },
  { modelValue: 'DEEPSEEKCODER', modelName: 'Deepseek Coder' },
  { modelValue: 'LLAMA3', modelName: 'LLaMA 3' },
];
