import Vue from 'vue';
import VueRouter from 'vue-router';
import { s__ } from '~/locale';
import { isLoggedIn } from '~/lib/utils/common_utils';
import NestedRouteApp from 'ee/ai/duo_agents_platform/nested_route_app.vue';
import AiCatalogAgents from '../pages/ai_catalog_agents.vue';
import AiCatalogAgent from '../pages/ai_catalog_agent.vue';
import AiCatalogAgentsEdit from '../pages/ai_catalog_agents_edit.vue';
import AiCatalogAgentsRun from '../pages/ai_catalog_agents_run.vue';
import AiCatalogAgentsNew from '../pages/ai_catalog_agents_new.vue';
import AiCatalogAgentsDuplicate from '../pages/ai_catalog_agents_duplicate.vue';
import AiCatalogFlow from '../pages/ai_catalog_flow.vue';
import AiCatalogFlows from '../pages/ai_catalog_flows.vue';
import AiCatalogFlowsEdit from '../pages/ai_catalog_flows_edit.vue';
import AiCatalogFlowsNew from '../pages/ai_catalog_flows_new.vue';
import {
  AI_CATALOG_INDEX_ROUTE,
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_EDIT_ROUTE,
  AI_CATALOG_AGENTS_RUN_ROUTE,
  AI_CATALOG_AGENTS_NEW_ROUTE,
  AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
  AI_CATALOG_FLOWS_NEW_ROUTE,
  AI_CATALOG_FLOWS_EDIT_ROUTE,
  AI_CATALOG_SHOW_QUERY_PARAM,
} from './constants';

Vue.use(VueRouter);

const requireAuth = (_, __, next) => {
  if (isLoggedIn()) {
    next();
  } else {
    next({ name: AI_CATALOG_INDEX_ROUTE });
  }
};

export const createRouter = (base) => {
  return new VueRouter({
    base,
    mode: 'history',
    routes: [
      {
        name: AI_CATALOG_INDEX_ROUTE,
        path: '',
        component: AiCatalogAgents,
      },
      // AGENTS
      {
        component: NestedRouteApp,
        path: '/agents',
        meta: {
          text: s__('AICatalog|Agents'),
        },
        children: [
          {
            name: AI_CATALOG_AGENTS_ROUTE,
            path: '',
            component: AiCatalogAgents,
          },
          {
            name: AI_CATALOG_AGENTS_NEW_ROUTE,
            path: 'new',
            component: AiCatalogAgentsNew,
            beforeEnter: requireAuth,
            meta: {
              text: s__('AICatalog|New agent'),
            },
          },
          // Catch-all route for /agents/:id - redirect to /agents?show=:id
          {
            path: ':id(\\d+)',
            redirect: (to) => ({
              path: '/agents',
              query: { [AI_CATALOG_SHOW_QUERY_PARAM]: to.params.id },
            }),
          },
          {
            path: ':id(\\d+)',
            component: AiCatalogAgent,
            children: [
              {
                name: AI_CATALOG_AGENTS_EDIT_ROUTE,
                path: 'edit',
                component: AiCatalogAgentsEdit,
                beforeEnter: requireAuth,
                meta: {
                  text: s__('AICatalog|Edit agent'),
                },
              },
              {
                name: AI_CATALOG_AGENTS_RUN_ROUTE,
                path: 'run',
                component: AiCatalogAgentsRun,
                beforeEnter: requireAuth,
                meta: {
                  text: s__('AICatalog|Run agent'),
                },
              },
              {
                name: AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
                path: 'duplicate',
                component: AiCatalogAgentsDuplicate,
                beforeEnter: requireAuth,
                meta: {
                  text: s__('AICatalog|Duplicate agent'),
                },
              },
            ],
          },
        ],
      },
      // FLOWS
      ...(gon.features?.aiCatalogFlows
        ? [
            {
              component: NestedRouteApp,
              path: '/flows',
              meta: {
                text: s__('AICatalog|Flows'),
              },
              children: [
                {
                  name: AI_CATALOG_FLOWS_ROUTE,
                  path: '',
                  component: AiCatalogFlows,
                },
                {
                  name: AI_CATALOG_FLOWS_NEW_ROUTE,
                  path: 'new',
                  component: AiCatalogFlowsNew,
                  beforeEnter: requireAuth,
                  meta: {
                    text: s__('AICatalog|New flow'),
                  },
                },
                // Catch-all route for /flows/:id - redirect to /flows?show=:id
                {
                  path: ':id(\\d+)',
                  redirect: (to) => ({
                    path: '/flows',
                    query: { [AI_CATALOG_SHOW_QUERY_PARAM]: to.params.id },
                  }),
                },
                {
                  path: ':id(\\d+)',
                  component: AiCatalogFlow,
                  children: [
                    {
                      name: AI_CATALOG_FLOWS_EDIT_ROUTE,
                      path: 'edit',
                      component: AiCatalogFlowsEdit,
                      beforeEnter: requireAuth,
                      meta: {
                        text: s__('AICatalog|Edit flow'),
                      },
                    },
                  ],
                },
              ],
            },
          ]
        : []),
      { path: '*', redirect: { name: AI_CATALOG_INDEX_ROUTE } },
    ],
  });
};
