export const mockAiFeatureSettings = [
  {
    name: 'Code Suggestions',
    subFeatures: [
      {
        name: 'Code generation',
        slug: 'code_generation',
        value: 0,
      },
      {
        name: 'Code completion',
        slug: 'code_completion',
        value: 1,
      },
    ],
  },
  {
    name: 'Duo Chat',
    subFeatures: [
      {
        name: 'Explain code',
        slug: 'duo_chat_explain_code',
        value: 2,
      },
      {
        name: 'Epic reader',
        slug: 'duo_chat_epic_reader',
        value: 3,
      },
    ],
  },
];

export const mockSelfHostedModels = [
  { id: 1, name: 'Model 1', model: 'mistral' },
  { id: 2, name: 'Model 2', model: 'mixtral' },
  { id: 3, name: 'Model 3', model: 'codegemma' },
];
