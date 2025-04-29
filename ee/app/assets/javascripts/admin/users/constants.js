import { GlFilteredSearchToken } from '@gitlab/ui';

import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';
import { s__ } from '~/locale';

import { ACCESS_LEVEL_TOKEN_TYPE, TOKENS as TOKENS_CE } from '~/admin/users/constants';

// eslint-disable-next-line import/export
export * from '~/admin/users/constants';

// eslint-disable-next-line import/export
export const TOKENS = [
  {
    title: s__('AdminUsers|Access level'),
    type: ACCESS_LEVEL_TOKEN_TYPE,
    token: GlFilteredSearchToken,
    operators: OPERATORS_IS,
    unique: true,
    options: [
      { value: 'admins', title: s__('AdminUsers|Administrator') },
      { value: 'auditors', title: s__('AdminUsers|Auditor') },
      { value: 'external', title: s__('AdminUsers|External') },
    ],
  },
  ...TOKENS_CE.filter((token) => token.type !== ACCESS_LEVEL_TOKEN_TYPE),
];
