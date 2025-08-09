import { s__ } from '~/locale';

import {
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';

export const TYPENAME_AI_CATALOG_ITEM = 'Ai::Catalog::Item';

export const AI_CATALOG_TYPE_AGENT = 'AGENT';
export const AI_CATALOG_TYPE_FLOW = 'FLOW';

export const PAGE_SIZE = 20;

// Matches backend validations in https://gitlab.com/gitlab-org/gitlab/blob/aa02c3080b316cf0f3b71a992bc5cc5dc8e8bb34/ee/app/models/ai/catalog/item.rb#L10
export const MAX_LENGTH_NAME = 255;
export const MAX_LENGTH_DESCRIPTION = 1024;
export const MAX_LENGTH_PROMPT = 1000000;

export const VISIBILITY_LEVEL_PRIVATE = 0;
export const VISIBILITY_LEVEL_PUBLIC = 20;
export const AGENT_VISIBILITY_LEVEL_DESCRIPTIONS = {
  [VISIBILITY_LEVEL_PUBLIC_STRING]: s__(
    'AICatalog|Anyone can view and use the agent without authorization. Only maintainers and owners of this project can edit or delete the agent.',
  ),
  [VISIBILITY_LEVEL_PRIVATE_STRING]: s__(
    'AICatalog|Only developers, maintainers and owners of this project can view and use the agent. Only maintainers and owners of this project can edit or delete the agent.',
  ),
};
export const FLOW_VISIBILITY_LEVEL_DESCRIPTIONS = {
  [VISIBILITY_LEVEL_PUBLIC_STRING]: s__(
    'AICatalog|Anyone can view and use the flow without authorization. Only maintainers and owners of this project can edit or delete the flow.',
  ),
  [VISIBILITY_LEVEL_PRIVATE_STRING]: s__(
    'AICatalog|Only developers, maintainers and owners of this project can view and use the flow. Only maintainers and owners of this project can edit or delete the flow.',
  ),
};
