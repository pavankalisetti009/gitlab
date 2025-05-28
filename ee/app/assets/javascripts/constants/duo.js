import { s__ } from '~/locale';

export const DUO_CORE = 'DUO_CORE';
export const DUO_PRO = 'CODE_SUGGESTIONS';
export const DUO_ENTERPRISE = 'DUO_ENTERPRISE';
export const DUO_AMAZON_Q = 'DUO_AMAZON_Q';

export const DUO_IDENTIFIERS = [DUO_CORE, DUO_PRO, DUO_ENTERPRISE, DUO_AMAZON_Q];

export const DUO_TITLES = {
  [DUO_CORE]: s__('CodeSuggestions|GitLab Duo Core'),
  [DUO_PRO]: s__('CodeSuggestions|GitLab Duo Pro'),
  [DUO_ENTERPRISE]: s__('CodeSuggestions|GitLab Duo Enterprise'),
  [DUO_AMAZON_Q]: s__('AmazonQ|GitLab Duo with Amazon Q'),
};
