import Vue from 'vue';
import VueRouter from 'vue-router';
import { s__ } from '~/locale';
import NestedRouteApp from 'ee/ai/duo_agents_platform/nested_route_app.vue';
import AiCatalogAgents from '../pages/ai_catalog_agents.vue';
import AiCatalogAgent from '../pages/ai_catalog_agent.vue';
import AiCatalogAgentsEdit from '../pages/ai_catalog_agents_edit.vue';
import AiCatalogAgentsRun from '../pages/ai_catalog_agents_run.vue';
import AiCatalogAgentsNew from '../pages/ai_catalog_agents_new.vue';
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
  AI_CATALOG_FLOWS_ROUTE,
  AI_CATALOG_FLOWS_NEW_ROUTE,
  AI_CATALOG_FLOWS_EDIT_ROUTE,
  AI_CATALOG_SHOW_QUERY_PARAM,
} from './constants';

Vue.use(VueRouter);

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
            meta: {
              text: s__('AICatalog|New agent'),
            },
          },
          // Catch-all route for /agents/:id - redirect to /agents?show=:id
          {
            path: ':id',
            redirect: (to) => ({
              path: '/agents',
              query: { [AI_CATALOG_SHOW_QUERY_PARAM]: to.params.id },
            }),
          },
          {
            path: ':id',
            component: AiCatalogAgent,
            children: [
              {
                name: AI_CATALOG_AGENTS_EDIT_ROUTE,
                path: 'edit',
                component: AiCatalogAgentsEdit,
                meta: {
                  text: s__('AICatalog|Edit agent'),
                },
              },
              {
                name: AI_CATALOG_AGENTS_RUN_ROUTE,
                path: 'run',
                component: AiCatalogAgentsRun,
                meta: {
                  text: s__('AICatalog|Run agent'),
                },
              },
            ],
          },
        ],
      },
      // FLOWS
      {
        name: AI_CATALOG_FLOWS_ROUTE,
        path: '/flows',
        component: AiCatalogFlows,
        meta: {
          text: s__('AICatalog|Flows'),
        },
      },
      {
        name: AI_CATALOG_FLOWS_NEW_ROUTE,
        path: '/flows/new',
        component: AiCatalogFlowsNew,
      },
      // Catch-all route for /flows/:id - redirect to /flows?show=:id
      {
        path: '/flows/:id',
        redirect: (to) => ({
          path: '/flows',
          query: { [AI_CATALOG_SHOW_QUERY_PARAM]: to.params.id },
        }),
      },
      {
        path: '/flows/:id',
        component: AiCatalogFlow,
        children: [
          {
            name: AI_CATALOG_FLOWS_EDIT_ROUTE,
            path: 'edit',
            component: AiCatalogFlowsEdit,
          },
        ],
      },
    ],
  });
};
