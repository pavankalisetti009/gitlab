import { __, s__ } from '~/locale';
import {
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';

import createAiCatalogAgent from './graphql/mutations/create_ai_catalog_agent.mutation.graphql';
import createAiCatalogFlow from './graphql/mutations/create_ai_catalog_flow.mutation.graphql';
import createAiCatalogThirdPartyFlow from './graphql/mutations/create_ai_catalog_third_party_flow.mutation.graphql';
import deleteAiCatalogAgentMutation from './graphql/mutations/delete_ai_catalog_agent.mutation.graphql';
import deleteAiCatalogFlowMutation from './graphql/mutations/delete_ai_catalog_flow.mutation.graphql';
import deleteAiCatalogThirdPartyFlowMutation from './graphql/mutations/delete_ai_catalog_third_party_flow.mutation.graphql';
import updateAiCatalogAgent from './graphql/mutations/update_ai_catalog_agent.mutation.graphql';
import updateAiCatalogFlow from './graphql/mutations/update_ai_catalog_flow.mutation.graphql';
import updateAiCatalogThirdPartyFlow from './graphql/mutations/update_ai_catalog_third_party_flow.mutation.graphql';

export const AI_CATALOG_TYPE_AGENT = 'AGENT';
export const AI_CATALOG_TYPE_FLOW = 'FLOW';
export const AI_CATALOG_TYPE_THIRD_PARTY_FLOW = 'THIRD_PARTY_FLOW';
export const AI_CATALOG_ITEM_LABELS = {
  [AI_CATALOG_TYPE_AGENT]: s__('AICatalog|agent'),
  [AI_CATALOG_TYPE_FLOW]: s__('AICatalog|flow'),
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: s__('AICatalog|agent'),
};
export const AI_CATALOG_ITEM_PLURAL_LABELS = {
  [AI_CATALOG_TYPE_AGENT]: s__('AICatalog|agents'),
  [AI_CATALOG_TYPE_FLOW]: s__('AICatalog|flows'),
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: s__('AICatalog|agents'),
};

export const AI_CATALOG_CONSUMER_TYPE_GROUP = 'group';
export const AI_CATALOG_CONSUMER_TYPE_PROJECT = 'project';
export const AI_CATALOG_CONSUMER_LABELS = {
  [AI_CATALOG_CONSUMER_TYPE_GROUP]: __('group'),
  [AI_CATALOG_CONSUMER_TYPE_PROJECT]: __('project'),
};
export const AI_CATALOG_GROUP_CONSUMER_LABEL_DESCRIPTION = {
  [AI_CATALOG_TYPE_AGENT]: s__(
    'AICatalog|You must have the Owner role to add an agent to a group. Only top-level groups are shown.',
  ),
  [AI_CATALOG_TYPE_FLOW]: s__(
    'AICatalog|You must have the Owner role to add a flow to a group. Only top-level groups are shown.',
  ),
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: s__(
    'AICatalog|You must have the Owner role to add an agent to a group. Only top-level groups are shown.',
  ),
};
export const AI_CATALOG_PROJECT_CONSUMER_LABEL_DESCRIPTION = {
  [AI_CATALOG_TYPE_AGENT]: s__(
    'AICatalog|Project members can use this agent. You must have at least the Maintainer role to add an agent to a project.',
  ),
  [AI_CATALOG_TYPE_FLOW]: s__(
    'AICatalog|Project members can use this flow. You must have at least the Maintainer role to add a flow to a project.',
  ),
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: s__(
    'AICatalog|Project members can use this agent. You must have at least the Maintainer role to add an agent to a project.',
  ),
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
    "AICatalog|This agent can be viewed only by members of this project, or by users with the Owner role for the top-level group. This agent can't be shared with other projects.",
  ),
};
export const FLOW_VISIBILITY_LEVEL_DESCRIPTIONS = {
  [VISIBILITY_LEVEL_PUBLIC_STRING]: s__('AICatalog|Anyone can view and use the flow.'),
  [VISIBILITY_LEVEL_PRIVATE_STRING]: s__(
    "AICatalog|This flow can be viewed only by members of this project, or by users with the Owner role for the top-level group. This flow can't be shared with other projects.",
  ),
};

export const TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX = 'view_ai_catalog_item_index';
export const TRACK_EVENT_VIEW_AI_CATALOG_ITEM = 'view_ai_catalog_item';
export const TRACK_EVENT_VIEW_AI_CATALOG_PROJECT_MANAGED = 'view_ai_catalog_project_managed';
export const TRACK_EVENT_ENABLE_AI_CATALOG_ITEM = 'click_enable_ai_catalog_item_button';
export const TRACK_EVENT_DISABLE_AI_CATALOG_ITEM = 'click_disable_ai_catalog_item_button';
export const TRACK_EVENT_DELETE_AI_CATALOG_ITEM = 'click_delete_ai_catalog_item_button';
export const TRACK_EVENT_DUPLICATE_AI_CATALOG_ITEM = 'click_duplicate_ai_catalog_item_button';
export const TRACK_EVENT_TYPE_AGENT = AI_CATALOG_TYPE_AGENT.toLowerCase();
export const TRACK_EVENT_TYPE_FLOW = AI_CATALOG_TYPE_FLOW.toLowerCase();
export const TRACK_EVENT_TYPE_THIRD_PARTY_FLOW = AI_CATALOG_TYPE_THIRD_PARTY_FLOW.toLowerCase();
export const TRACK_EVENT_ITEM_TYPES = {
  [AI_CATALOG_TYPE_AGENT]: TRACK_EVENT_TYPE_AGENT,
  [AI_CATALOG_TYPE_FLOW]: TRACK_EVENT_TYPE_FLOW,
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: TRACK_EVENT_TYPE_THIRD_PARTY_FLOW,
};
export const TRACK_EVENT_ORIGIN_EXPLORE = 'explore';
export const TRACK_EVENT_ORIGIN_PROJECT = 'project';
export const TRACK_EVENT_ORIGIN_GROUP = 'group';
export const TRACK_EVENT_PAGE_LIST = 'list';
export const TRACK_EVENT_PAGE_SHOW = 'show';

export const VERSION_LATEST = 'latestVersion';
export const VERSION_PINNED = 'configurationForProject.pinnedItemVersion';
export const VERSION_PINNED_GROUP = 'configurationForGroup.pinnedItemVersion';

export const AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG = {
  [AI_CATALOG_TYPE_AGENT]: {
    create: {
      mutation: createAiCatalogAgent,
      responseKey: 'aiCatalogAgentCreate',
    },
    delete: {
      mutation: deleteAiCatalogAgentMutation,
      responseKey: 'aiCatalogAgentDelete',
    },
    update: {
      mutation: updateAiCatalogAgent,
      responseKey: 'aiCatalogAgentUpdate',
    },
  },
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

export const ENABLE_AGENT_MODAL_TEXTS = {
  title: s__('AICatalog|Enable agent in your project'),
  label: s__('AICatalog|Agent'),
  labelDescription: s__('AICatalog|Only agents enabled in your top-level group are shown.'),
  invalidFeedback: s__('AICatalog|Agent is required.'),
  error: s__('AICatalog|Failed to load group agents'),
  dropdownTexts: {
    placeholder: s__('AICatalog|Select an agent'),
    itemSublabel: s__('AICatalog|Agent ID: %{id}'),
  },
};
export const ENABLE_FLOW_MODAL_TEXTS = {
  title: s__('AICatalog|Enable flow in your project'),
  label: s__('AICatalog|Flow'),
  labelDescription: s__('AICatalog|Only flows enabled in your top-level group are shown.'),
  invalidFeedback: s__('AICatalog|Flow is required.'),
  error: s__('AICatalog|Failed to load group flows'),
  dropdownTexts: {
    placeholder: s__('AICatalog|Select a flow'),
    itemSublabel: s__('AICatalog|Flow ID: %{id}'),
  },
};

export const DEFAULT_FLOW_YML_STRING = `\
# Schema version
version: "v1"
# Environment where the flow runs (ambient = GitLab's managed environment)
environment: ambient

# Components define the steps in your flow
# Each component can be an Agent, DeterministicStep, or other component types
components:
  - name: "my_agent"
    type: AgentComponent  # Options: AgentComponent, DeterministicStepComponent
    prompt_id: "my_prompt"  # References a prompt defined below
    inputs:
      - "context:goal"  # Input from user or previous component
    toolset: []  # Add tool names here: ["get_issue", "create_issue_note"]

    # Optional: UI logging
    ui_log_events:
      - "on_agent_final_answer"
      - "on_tool_execution_success"

# Define your prompts here
# Each prompt configures an AI agent's behavior
prompts:
  - prompt_id: "my_prompt"  # Must match the prompt_id referenced above
    name: "My Agent Prompt"

    # System and user prompts define the agent's behavior
    prompt_template:
      system: |
        You are GitLab Duo Chat, an agentic AI assistant.
        Your role is to help users with their GitLab tasks.
        Be concise, accurate, and actionable in your responses.

        # Add specific instructions for your use case here

      # Available variables depend on your inputs:
      # {{goal}} - The user's request
      # {{context}} - Additional context from previous steps
      user: |
        {{goal}}

      placeholder: history  # Maintains conversation context

    unit_primitives: []
    params:
      timeout: 180  # Seconds before timeout

# Routers define the flow between components
# Use "end" as the final destination
routers:
  - from: "my_agent"
    to: "end"

  # Example: Multi-step flow
  # - from: "fetch_data"
  #   to: "process_data"
  # - from: "process_data"
  #   to: "my_agent"
  # - from: "my_agent"
  #   to: "end"

# Define the entry point for your flow
flow:
  entry_point: "my_agent"
`;

export const DEFAULT_THIRD_PARTY_FLOW_YML_STRING = `\
image: alpine:latest
injectGatewayToken: true
commands:
  - echo "Hello, World!"
`;
