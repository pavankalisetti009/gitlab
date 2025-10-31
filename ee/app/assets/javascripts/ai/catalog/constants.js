import { uniqueId } from 'lodash';
import { __, s__ } from '~/locale';

import {
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';

import createAiCatalogFlow from './graphql/mutations/create_ai_catalog_flow.mutation.graphql';
import createAiCatalogThirdPartyFlow from './graphql/mutations/create_ai_catalog_third_party_flow.mutation.graphql';
import deleteAiCatalogFlowMutation from './graphql/mutations/delete_ai_catalog_flow.mutation.graphql';
import deleteAiCatalogThirdPartyFlowMutation from './graphql/mutations/delete_ai_catalog_third_party_flow.mutation.graphql';
import updateAiCatalogFlow from './graphql/mutations/update_ai_catalog_flow.mutation.graphql';
import updateAiCatalogThirdPartyFlow from './graphql/mutations/update_ai_catalog_third_party_flow.mutation.graphql';

export const AI_CATALOG_TYPE_AGENT = 'AGENT';
export const AI_CATALOG_TYPE_FLOW = 'FLOW';
export const AI_CATALOG_TYPE_THIRD_PARTY_FLOW = 'THIRD_PARTY_FLOW';
export const AI_CATALOG_ITEM_LABELS = {
  [AI_CATALOG_TYPE_AGENT]: s__('AICatalog|agent'),
  [AI_CATALOG_TYPE_FLOW]: s__('AICatalog|flow'),
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: s__('AICatalog|flow'),
};
export const AI_CATALOG_ITEM_PLURAL_LABELS = {
  [AI_CATALOG_TYPE_AGENT]: s__('AICatalog|agents'),
  [AI_CATALOG_TYPE_FLOW]: s__('AICatalog|flows'),
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: s__('AICatalog|flows'),
};

export const AI_CATALOG_CONSUMER_TYPE_GROUP = 'group';
export const AI_CATALOG_CONSUMER_TYPE_PROJECT = 'project';
export const AI_CATALOG_CONSUMER_LABELS = {
  [AI_CATALOG_CONSUMER_TYPE_GROUP]: __('group'),
  [AI_CATALOG_CONSUMER_TYPE_PROJECT]: __('project'),
};

export const MINIMUM_QUERY_LENGTH = 3;
export const PAGE_SIZE = 20;

// Matches backend validations in https://gitlab.com/gitlab-org/gitlab/blob/aa02c3080b316cf0f3b71a992bc5cc5dc8e8bb34/ee/app/models/ai/catalog/item.rb#L10
export const MAX_LENGTH_NAME = 255;
export const MAX_LENGTH_DESCRIPTION = 1024;
export const MAX_LENGTH_PROMPT = 1000000;

export const VISIBILITY_LEVEL_PRIVATE = 0;
export const VISIBILITY_LEVEL_PUBLIC = 20;
export const AGENT_VISIBILITY_LEVEL_DESCRIPTIONS = {
  [VISIBILITY_LEVEL_PUBLIC_STRING]: s__('AICatalog|Anyone can view and use the agent.'),
  [VISIBILITY_LEVEL_PRIVATE_STRING]: s__(
    "AICatalog|Only members of this project can view this agent. This agent can't be shared with other projects.",
  ),
};
export const FLOW_VISIBILITY_LEVEL_DESCRIPTIONS = {
  [VISIBILITY_LEVEL_PUBLIC_STRING]: s__('AICatalog|Anyone can view and use the flow.'),
  [VISIBILITY_LEVEL_PRIVATE_STRING]: s__(
    "AICatalog|Only members of this project can view this flow. This flow can't be shared with other projects.",
  ),
};

export const TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX = 'view_ai_catalog_item_index';
export const TRACK_EVENT_VIEW_AI_CATALOG_ITEM = 'view_ai_catalog_item';
export const TRACK_EVENT_TYPE_AGENT = AI_CATALOG_TYPE_AGENT.toLowerCase();
export const TRACK_EVENT_TYPE_FLOW = AI_CATALOG_TYPE_FLOW.toLowerCase();

// FLOW and THIRD_PARTY_FLOW apollo configuration
export const FLOW_TYPE_APOLLO_CONFIG = {
  [AI_CATALOG_TYPE_FLOW]: {
    create: {
      mutation: createAiCatalogFlow,
      responseKey: 'aiCatalogFlowCreate',
    },
    delete: {
      mutation: deleteAiCatalogFlowMutation,
      responseKey: 'aiCatalogFlowDelete',
    },
    update: {
      mutation: updateAiCatalogFlow,
      responseKey: 'aiCatalogFlowUpdate',
    },
  },
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: {
    create: {
      mutation: createAiCatalogThirdPartyFlow,
      responseKey: 'aiCatalogThirdPartyFlowCreate',
    },
    delete: {
      mutation: deleteAiCatalogThirdPartyFlowMutation,
      responseKey: 'aiCatalogThirdPartyFlowDelete',
    },
    update: {
      mutation: updateAiCatalogThirdPartyFlow,
      responseKey: 'aiCatalogThirdPartyFlowUpdate',
    },
  },
};

export const FORM_ID_TEST_RUN = uniqueId('ai-catalog-agent-run-form-');
