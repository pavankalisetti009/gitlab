export const mockAiFeatureSettings = [
  {
    feature: 'code_generations',
    title: 'Code Generation',
    mainFeature: 'Code Suggestions',
    provider: 'self_hosted',
    selfHostedModel: null,
  },
  {
    feature: 'code_completions',
    title: 'Code Completion',
    mainFeature: 'Code Suggestions',
    provider: 'vendored',
    selfHostedModel: null,
  },
  {
    feature: 'duo_chat',
    title: 'Duo Chat',
    mainFeature: 'Duo Chat',
    provider: 'self_hosted',
    selfHostedModel: null,
  },
];

export const mockSelfHostedModels = [
  { id: 1, name: 'Model 1', model: 'mistral' },
  { id: 2, name: 'Model 2', model: 'mixtral' },
  { id: 3, name: 'Model 3', model: 'codegemma' },
];
