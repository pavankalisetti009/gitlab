export const mockSelfHostedModel = {
  id: 'gid://gitlab/SelfHostedModel/1',
  name: 'mock-self-hosted-model',
  model: 'mixtral',
  endpoint: 'https://mock-endpoint.com',
  apiToken: '',
};

export const mockSelfHostedModelsList = [
  {
    id: 'gid://gitlab/SelfHostedModel/1',
    name: 'mock-self-hosted-model-1',
    model: 'mixtral',
    endpoint: 'https://mock-endpoint-1.com',
    hasApiToken: true,
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
  { modelValue: 'CODEGEMMA_2B', modelName: 'CodeGemma 2b' },
  { modelValue: 'CODEGEMMA', modelName: 'CodeGemma 7b-it' },
  { modelValue: 'CODEGEMMA_7B', modelName: 'CodeGemma 7b' },
  { modelValue: 'CODELLAMA_13B_CODE', modelName: 'Code-Llama 13b-code' },
  { modelValue: 'CODELLAMA', modelName: 'Code-Llama 13b' },
  { modelValue: 'CODESTRAL', modelName: 'Codestral 22B' },
  { modelValue: 'MISTRAL', modelName: 'Mistral 7B' },
  { modelValue: 'MIXTRAL_8X22B', modelName: 'Mixtral 8x22B' },
  { modelValue: 'MIXTRAL', modelName: 'Mixtral 8x7B' },
  { modelValue: 'DEEPSEEKCODER', modelName: 'DEEPSEEKCODER' },
  { modelValue: 'MISTRAL_TEXT', modelName: 'Mistral Text 7B' },
  { modelValue: 'MIXTRAL_TEXT', modelName: 'Mixtral Text 8x7B' },
  { modelValue: 'MIXTRAL_8X22B_TEXT', modelName: 'Mixtral Text 8X22B' },
  { modelValue: 'LLAMA3', modelName: 'LLaMA 3 - 13B' },
  { modelValue: 'LLAMA3_TEXT', modelName: 'LLaMA 3 - 13B Text' },
  { modelValue: 'LLAMA3_70B', modelName: 'LLaMA 3 - 70B' },
  { modelValue: 'LLAMA3_70B_TEXT', modelName: 'LLaMA 3 - 70B Text' },
];
