export const mockCodeSuggestionsFeatureSettings = [
  {
    feature: 'code_completions',
    title: 'Code Completion',
    mainFeature: 'Code Suggestions',
    selectedModel: {
      ref: 'claude_sonnet_3_7_20250219',
      name: 'Claude Sonnet 3.7 - Anthropic',
    },
    defaultModel: {
      name: 'Claude Sonnet 3.7 - Anthropic',
    },
    selectableModels: [
      {
        ref: 'claude_sonnet_3_7_20250219',
        name: 'Claude Sonnet 3.7 - Anthropic',
      },
      {
        ref: 'claude_3_5_sonnet_20240620',
        name: 'Claude Sonnet 3.5 - Anthropic',
      },
      {
        ref: 'claude_3_haiku_20240307"',
        name: 'Claude Haiku 3 - Anthropic',
      },
    ],
  },
  {
    feature: 'code_generations',
    title: 'Code Generation',
    mainFeature: 'Code Suggestions',
    selectedModel: {
      ref: '',
      name: 'GitLab Default',
    },
    defaultModel: {
      name: 'Claude Sonnet 3.7 - Anthropic',
    },
    selectableModels: [
      {
        ref: 'claude_sonnet_3_7_20250219',
        name: 'Claude Sonnet 3.7 - Anthropic',
      },
      {
        ref: 'claude_3_5_sonnet_20240620',
        name: 'Claude Sonnet 3.5 - Anthropic',
      },
      {
        ref: 'claude_3_haiku_20240307"',
        name: 'Claude Haiku 3 - Anthropic',
      },
    ],
  },
];

export const mockDuoChatFeatureSettings = [
  {
    feature: 'duo_chat',
    title: 'General Chat',
    mainFeature: 'GitLab Duo Chat',
    selectedModel: null,
    defaultModel: {
      name: 'Claude Sonnet 3.7 - Anthropic',
    },
    selectableModels: [
      {
        ref: 'claude_sonnet_3_7_20250219',
        name: 'Claude Sonnet 3.7 - Anthropic',
      },
      {
        ref: 'claude_3_5_sonnet_20240620',
        name: 'Claude Sonnet 3.5 - Anthropic',
      },
      {
        ref: 'claude_3_haiku_20240307',
        name: 'Claude Haiku 3 - Anthropic',
      },
    ],
  },
];

export const mockMergeRequestFeatureSettings = [
  {
    feature: 'summarize_review',
    title: 'Code Review Summary',
    mainFeature: 'GitLab Duo for merge requests',
    selectedModel: null,
    defaultModel: {
      name: 'Claude Sonnet 3.7 - Anthropic',
    },
    selectableModels: [
      {
        ref: 'claude_sonnet_3_7_20250219',
        name: 'Claude Sonnet 3.7 - Anthropic',
      },
      {
        ref: 'claude_3_5_sonnet_20240620',
        name: 'Claude Sonnet 3.5 - Anthropic',
      },
      {
        ref: 'claude_3_haiku_20240307',
        name: 'Claude Haiku 3 - Anthropic',
      },
    ],
  },
  {
    feature: 'generate_commit_message',
    title: 'Merge Commit Message Generation',
    mainFeature: 'GitLab Duo for merge requests',
    selectedModel: null,
    defaultModel: {
      name: 'Claude Sonnet 3.7 - Anthropic',
    },
    selectableModels: [
      {
        ref: 'claude_sonnet_3_7_20250219',
        name: 'Claude Sonnet 3.7 - Anthropic',
      },
      {
        ref: 'claude_3_5_sonnet_20240620',
        name: 'Claude Sonnet 3.5 - Anthropic',
      },
      {
        ref: 'claude_3_haiku_20240307',
        name: 'Claude Haiku 3 - Anthropic',
      },
    ],
  },
];

export const mockIssueFeatureSettings = [
  {
    feature: 'duo_chat_summarize_comments',
    title: 'Discussion Summary',
    mainFeature: 'GitLab Duo for issues',
    selectedModel: {
      ref: 'claude_3_5_sonnet_20240620',
      name: 'Claude Sonnet 3.5 - Anthropic',
    },
    defaultModel: {
      name: 'Claude Sonnet 3.7 - Anthropic',
    },
    selectableModels: [
      {
        ref: 'claude_sonnet_3_7_20250219',
        name: 'Claude Sonnet 3.7 - Anthropic',
      },
      {
        ref: 'claude_3_5_sonnet_20240620',
        name: 'Claude Sonnet 3.5 - Anthropic',
      },
      {
        ref: 'claude_3_haiku_20240307',
        name: 'Claude Haiku 3 - Anthropic',
      },
    ],
  },
];

export const mockOtherDuoFeaturesSettings = [
  {
    feature: 'glab_ask_git_command',
    title: 'GitLab Duo for CLI',
    mainFeature: 'Other GitLab Duo features',
    selectedModel: {
      ref: 'claude_3_5_sonnet_20240620',
      name: 'Claude Sonnet 3.5 - Anthropic',
    },
    defaultModel: {
      name: 'Claude Sonnet 3.7 - Anthropic',
    },
    selectableModels: [
      {
        ref: 'claude_sonnet_3_7_20250219',
        name: 'Claude Sonnet 3.7 - Anthropic',
      },
      {
        ref: 'claude_3_5_sonnet_20240620',
        name: 'Claude Sonnet 3.5 - Anthropic',
      },
      {
        ref: 'claude_3_haiku_20240307"',
        name: 'Claude Haiku 3 - Anthropic',
      },
    ],
  },
];

export const mockAiFeatureSettings = [
  ...mockCodeSuggestionsFeatureSettings,
  ...mockDuoChatFeatureSettings,
  ...mockMergeRequestFeatureSettings,
  ...mockIssueFeatureSettings,
  ...mockOtherDuoFeaturesSettings,
];

export const selfHostedModelslistItems = [
  { value: 'CLAUDE_3', text: 'Claude 3', releaseState: 'GA' },
  { value: 'CODELLAMA', text: 'Code Llama', releaseState: 'BETA' },
  { value: 'CODEGEMMA', text: 'CodeGemma', releaseState: 'BETA' },
  { value: 'DEEPSEEKCODER', text: 'DeepSeek Coder', releaseState: 'BETA' },
  { value: 'GPT', text: 'GPT', releaseState: 'GA' },
];

export const modelSelectionListItems = [
  { value: 'claude_3_5_sonnet_20240620', text: 'Claude Sonnet 3.5 - Anthropic' },
  { value: 'claude_3_7_sonnet_20240620', text: 'Claude Sonnet 3.7 - Anthropic' },
  { value: 'claude_3_haiku_20240307', text: 'Claude Haiku 3 - Anthropic' },
  { value: '', text: 'GitLab Default (Claude Sonnet 3.7 - Anthropic)' },
];

export const featureSettingsListItems = [
  { value: 'gid://gitlab/Ai::SelfHostedModel/1', text: 'Claude 3 deployment', releaseState: 'GA' },
  {
    value: 'gid://gitlab/Ai::SelfHostedModel/2',
    text: 'Code Llama deployment',
    releaseState: 'BETA',
  },
  {
    value: 'gid://gitlab/Ai::SelfHostedModel/3',
    text: 'CodeGemma deployment',
    releaseState: 'BETA',
  },
  {
    value: 'gid://gitlab/Ai::SelfHostedModel/4',
    text: 'DeepSeek Coder deployment',
    releaseState: 'BETA',
  },
  {
    value: 'gid://gitlab/Ai::SelfHostedModel/5',
    text: 'GPT deployment',
    releaseState: 'GA',
  },
  { value: 'disabled', text: 'Disable' },
  { value: 'vendored', text: 'GitLab AI Vendor' },
];
