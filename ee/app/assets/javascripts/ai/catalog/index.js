import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlToast } from '@gitlab/ui';

import createDefaultClient from '~/lib/graphql';

import AiCatalogApp from './ai_catalog_app.vue';
import { createRouter } from './router';

import aiCatalogAgentsQuery from './graphql/ai_catalog_agents.query.graphql';
import aiCatalogAgentQuery from './graphql/ai_catalog_agent.query.graphql';

export const initAiCatalog = (selector = '#js-ai-catalog') => {
  const el = document.querySelector(selector);

  if (!el) {
    return null;
  }

  const { dataset } = el;
  const { aiCatalogIndexPath } = dataset;

  Vue.use(VueApollo);
  Vue.use(GlToast);

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  /* eslint-disable @gitlab/require-i18n-strings */
  const agent1 = {
    id: 1,
    type: 'agent',
    name: 'Claude Sonnet 4',
    description: 'Smart, efficient model for everyday user',
    model: 'claude-sonnet-4-20250514',
    verified: true,
    version: 'v4.2',
    releasedAt: new Date(),
    systemPrompt:
      'You are a coding assistant focused on clean, efficient code. Provide working examples, explain your reasoning, and suggest best practices. Always include error handling and consider performance implications.',
    userPrompt:
      'Create a Vue component that displays a list of users with search functionality and handles loading states.',
  };

  const agent2 = {
    id: 2,
    type: 'agent',
    name: 'Claude Opus 4',
    description: 'Powerful, large model for complex challenges',
    model: 'claude-opus-4-20250514',
    verified: true,
    version: 'v4.2',
    releasedAt: new Date(),
    systemPrompt:
      'You are a strategic business consultant with expertise in market analysis, competitive intelligence, and strategic planning. Provide comprehensive insights backed by logical reasoning. Consider multiple stakeholders, potential risks, and implementation challenges in your recommendations.',
    userPrompt:
      'Our SaaS company is considering expanding into the European market. Analyze the key factors we should evaluate, potential entry strategies, and create a risk assessment framework for this expansion.',
  };
  /* eslint-enable @gitlab/require-i18n-strings */

  apolloProvider.clients.defaultClient.cache.writeQuery({
    query: aiCatalogAgentsQuery,
    data: {
      aiCatalogAgents: {
        nodes: [agent1, agent2],
      },
    },
  });

  apolloProvider.clients.defaultClient.cache.writeQuery({
    query: aiCatalogAgentQuery,
    variables: { id: '1' },
    data: {
      aiCatalogAgent: agent1,
    },
  });

  apolloProvider.clients.defaultClient.cache.writeQuery({
    query: aiCatalogAgentQuery,
    variables: { id: '2' },
    data: {
      aiCatalogAgent: agent2,
    },
  });

  return new Vue({
    el,
    name: 'AiCatalogRoot',
    router: createRouter(aiCatalogIndexPath),
    apolloProvider,
    render(h) {
      return h(AiCatalogApp);
    },
  });
};
