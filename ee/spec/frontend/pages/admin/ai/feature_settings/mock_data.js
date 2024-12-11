export const mockSelfHostedModels = [
  { id: 1, name: 'Model 1', model: 'mistral', modelDisplayName: 'Mistral' },
  { id: 2, name: 'Model 2', model: 'codellama', modelDisplayName: 'Code Llama' },
  { id: 3, name: 'Model 3', model: 'codegemma', modelDisplayName: 'CodeGemma' },
];

export const mockAiFeatureSettings = [
  {
    feature: 'code_generations',
    title: 'Code Generation',
    mainFeature: 'Code Suggestions',
    provider: 'vendored',
    selfHostedModel: null,
    validModels: { nodes: mockSelfHostedModels },
  },
  {
    feature: 'code_completions',
    title: 'Code Completion',
    mainFeature: 'Code Suggestions',
    provider: 'disabled',
    selfHostedModel: null,
    validModels: { nodes: mockSelfHostedModels },
  },
  {
    feature: 'duo_chat',
    title: 'Duo Chat',
    mainFeature: 'Duo Chat',
    provider: 'self_hosted',
    selfHostedModel: {
      id: 2,
      name: 'Model 2',
      model: 'codellama',
    },
    validModels: { nodes: mockSelfHostedModels },
  },
];
