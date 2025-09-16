export const MOCK_AI_CHAT_AVAILABLE_MODELS_RESPONSE = {
  data: {
    aiChatAvailableModels: {
      defaultModel: {
        name: 'Claude Sonnet 4.0 - Anthropic',
        ref: 'claude_sonnet_4_20250514',
      },
      selectableModels: [
        {
          name: 'Claude Sonnet 4.0 - Anthropic',
          ref: 'claude_sonnet_4_20250514',
        },
        {
          name: 'Claude Sonnet 3.7 - Anthropic',
          ref: 'claude_sonnet_3_7_20250219',
        },
        {
          name: 'Claude Sonnet 3.5 - Anthropic',
          ref: 'claude_3_5_sonnet_20240620',
        },
      ],
    },
  },
};

export const MOCK_GITLAB_DEFAULT_MODEL_ITEM = {
  value: '',
  text: 'Claude Sonnet 4.0 - Anthropic',
};

export const MOCK_MODEL_LIST_ITEMS = [
  MOCK_GITLAB_DEFAULT_MODEL_ITEM,
  { text: 'Claude Sonnet 3.7 - Anthropic', value: 'claude_sonnet_3_7_20250219' },
  { text: 'Claude Sonnet 3.5 - Anthropic', value: 'claude_3_5_sonnet_20240620' },
];
