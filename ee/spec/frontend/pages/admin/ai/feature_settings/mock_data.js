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
