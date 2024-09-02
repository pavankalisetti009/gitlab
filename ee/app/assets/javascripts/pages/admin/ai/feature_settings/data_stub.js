/**
 * Temporary data stub for feature settings table
 *
 * TODO: Remove when feature settings data is ready.
 * See https://gitlab.com/gitlab-org/gitlab/-/issues/473005#note_2076997154
 */

/* eslint-disable @gitlab/require-i18n-strings */
const stubbedAiFeatureSettings = [
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
        value: 3,
      },
      {
        name: 'Epic reader',
        slug: 'duo_chat_epic_reader',
        value: 3,
      },
    ],
  },
];
/* eslint-enable @gitlab/require-i18n-strings */

export default stubbedAiFeatureSettings;
