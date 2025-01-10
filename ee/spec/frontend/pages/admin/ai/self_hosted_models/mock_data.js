import { BEDROCK_DUMMY_ENDPOINT } from 'ee/pages/admin/ai/self_hosted_models/constants';

export const mockSelfHostedModel = {
  id: 'gid://gitlab/Ai::SelfHostedModel/1',
  name: 'mock-self-hosted-model',
  model: 'mistral',
  modelDisplayName: 'Mistral',
  endpoint: 'https://mock-endpoint.com',
  identifier: 'provider/some-model-1',
  apiToken: 'mock-api-token-123',
  featureSettings: {
    nodes: [],
  },
};

export const mockBedrockSelfHostedModel = {
  id: 'gid://gitlab/Ai::SelfHostedModel/1',
  name: 'mock-bedrock-model',
  model: 'mistral',
  modelDisplayName: 'Mistral',
  endpoint: BEDROCK_DUMMY_ENDPOINT,
  identifier: 'bedrock/some-model-1',
  apiToken: '',
  featureSettings: {
    nodes: [],
  },
};

export const mockSelfHostedModelsList = [
  {
    id: 'gid://gitlab/Ai::SelfHostedModel/1',
    name: 'mock-self-hosted-model-1',
    model: 'codellama',
    modelDisplayName: 'Code Llama',
    endpoint: 'https://mock-endpoint-1.com',
    identifier: 'provider/some-model-1',
    hasApiToken: true,
    featureSettings: {
      nodes: [
        {
          title: 'Code Completion',
          feature: 'code_completions',
        },
      ],
    },
  },
  {
    id: 'gid://gitlab/Ai::SelfHostedModel/2',
    name: 'mock-self-hosted-model-2',
    model: 'mistral',
    modelDisplayName: 'Mistral',
    endpoint: 'https://mock-endpoint-2.com',
    identifier: '',
    hasApiToken: true,
    featureSettings: {
      nodes: [],
    },
  },
  {
    id: 'gid://gitlab/Ai::SelfHostedModel/3',
    name: 'mock-bedrock-self-hosted-model',
    model: 'mistral',
    modelDisplayName: 'Mistral',
    endpoint: BEDROCK_DUMMY_ENDPOINT,
    identifier: 'bedrock/example-model',
    hasApiToken: false,
    featureSettings: {
      nodes: [],
    },
  },
];

export const mockModelConnectionTestInput = {
  name: 'mock-self-hosted-model-1',
  model: 'MISTRAL',
  endpoint: 'https://mock-endpoint.com',
  identifier: '',
  apiToken: 'mock-api-token-123',
};

export const SELF_HOSTED_MODEL_OPTIONS = [
  { modelValue: 'CODEGEMMA', modelName: 'CodeGemma' },
  { modelValue: 'CODELLAMA', modelName: 'Code-Llama' },
  { modelValue: 'CODESTRAL', modelName: 'Codestral' },
  { modelValue: 'MISTRAL', modelName: 'Mistral' },
  { modelValue: 'DEEPSEEKCODER', modelName: 'Deepseek Coder' },
  { modelValue: 'LLAMA3', modelName: 'Llama 3' },
];
