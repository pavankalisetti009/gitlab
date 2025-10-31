import Vue from 'vue';
import VueRouter from 'vue-router';
import { s__ } from '~/locale';
import {
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_SHOW_ROUTE,
  AI_CATALOG_AGENTS_NEW_ROUTE,
  AI_CATALOG_AGENTS_EDIT_ROUTE,
  AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
  AI_CATALOG_FLOWS_SHOW_ROUTE,
  AI_CATALOG_FLOWS_NEW_ROUTE,
  AI_CATALOG_FLOWS_EDIT_ROUTE,
  AI_CATALOG_FLOWS_DUPLICATE_ROUTE,
} from 'ee/ai/catalog/router/constants';
import AiCatalogAgent from 'ee/ai/catalog/pages/ai_catalog_agent.vue';
import AiCatalogAgentsShow from 'ee/ai/catalog/pages/ai_catalog_agents_show.vue';
import AiCatalogAgentsNew from 'ee/ai/catalog/pages/ai_catalog_agents_new.vue';
import AiCatalogAgentsEdit from 'ee/ai/catalog/pages/ai_catalog_agents_edit.vue';
import AiCatalogAgentsDuplicate from 'ee/ai/catalog/pages/ai_catalog_agents_duplicate.vue';
import AiCatalogFlow from 'ee/ai/catalog/pages/ai_catalog_flow.vue';
import AiCatalogFlowsShow from 'ee/ai/catalog/pages/ai_catalog_flows_show.vue';
import AiCatalogFlowsNew from 'ee/ai/catalog/pages/ai_catalog_flows_new.vue';
import AiCatalogFlowsEdit from 'ee/ai/catalog/pages/ai_catalog_flows_edit.vue';
import AiCatalogFlowsDuplicate from 'ee/ai/catalog/pages/ai_catalog_flows_duplicate.vue';
import NestedRouteApp from '../nested_route_app.vue';
import AgentsPlatformShow from '../pages/show/duo_agents_platform_show.vue';
import FlowTriggersIndex from '../pages/flow_triggers/index/flow_triggers_index.vue';
import FlowTriggersNew from '../pages/flow_triggers/flow_triggers_new.vue';
import FlowTriggersEdit from '../pages/flow_triggers/flow_triggers_edit.vue';
import AiAgentsIndex from '../pages/agents/ai_agents_index.vue';
import AiFlowsIndex from '../pages/flows/ai_flows_index.vue';
import {
  AGENTS_PLATFORM_INDEX_ROUTE,
  AGENTS_PLATFORM_SHOW_ROUTE,
  FLOW_TRIGGERS_INDEX_ROUTE,
  FLOW_TRIGGERS_NEW_ROUTE,
  FLOW_TRIGGERS_EDIT_ROUTE,
} from './constants';
import { getNamespaceIndexComponent } from './utils';

Vue.use(VueRouter);

export const createRouter = (base, namespace) => {
  return new VueRouter({
    base,
    mode: 'history',
    routes: [
      {
        component: NestedRouteApp,
        path: '/agent-sessions',
        meta: {
          text: s__('DuoAgentsPlatform|Sessions'),
        },
        children: [
          {
            name: AGENTS_PLATFORM_INDEX_ROUTE,
            path: '',
            component: getNamespaceIndexComponent(namespace),
          },
          // Used as hardcoded path in
          // https://gitlab.com/gitlab-org/gitlab/-/blob/e9b59c5de32c6ce4e14665681afbf95cf001c044/ee/app/assets/javascripts/ai/components/duo_workflow_action.vue#L76.
          {
            name: AGENTS_PLATFORM_SHOW_ROUTE,
            path: ':id(\\d+)',
            component: AgentsPlatformShow,
            meta: {
              useId: true,
            },
          },
        ],
      },
      {
        component: NestedRouteApp,
        path: '/flow-triggers',
        meta: {
          text: s__('DuoAgentsPlatform|Flow triggers'),
        },
        children: [
          {
            name: FLOW_TRIGGERS_INDEX_ROUTE,
            path: '',
            component: FlowTriggersIndex,
          },
          {
            name: FLOW_TRIGGERS_NEW_ROUTE,
            path: 'new',
            component: FlowTriggersNew,
            meta: {
              text: s__('DuoAgentsPlatform|New flow trigger'),
            },
          },
          {
            path: ':id(\\d+)/edit',
            component: FlowTriggersEdit,
            name: FLOW_TRIGGERS_EDIT_ROUTE,
            meta: {
              text: s__('DuoAgentsPlatform|Edit flow trigger'),
            },
          },
          {
            path: ':id/edit',
            redirect: '/flow-triggers',
          },
        ],
      },
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
            component: AiAgentsIndex,
          },
          ...(gon.features?.aiCatalogItemProjectCuration
            ? [
                {
                  name: AI_CATALOG_AGENTS_NEW_ROUTE,
                  path: 'new',
                  component: AiCatalogAgentsNew,
                  meta: {
                    text: s__('AICatalog|New agent'),
                  },
                },
                {
                  path: ':id(\\d+)',
                  component: AiCatalogAgent,
                  meta: {
                    useId: true,
                    defaultRoute: AI_CATALOG_AGENTS_SHOW_ROUTE,
                  },
                  children: [
                    {
                      name: AI_CATALOG_AGENTS_SHOW_ROUTE,
                      path: '',
                      component: AiCatalogAgentsShow,
                    },
                    {
                      name: AI_CATALOG_AGENTS_EDIT_ROUTE,
                      path: 'edit',
                      component: AiCatalogAgentsEdit,
                      meta: {
                        text: s__('AICatalog|Edit agent'),
                      },
                    },
                    {
                      name: AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
                      path: 'duplicate',
                      component: AiCatalogAgentsDuplicate,
                      meta: {
                        text: s__('AICatalog|Duplicate agent'),
                      },
                    },
                  ],
                },
              ]
            : [
                {
                  path: ':id(\\d+)',
                  component: AiCatalogAgent,
                  meta: {
                    useId: true,
                  },
                  children: [
                    {
                      name: AI_CATALOG_AGENTS_SHOW_ROUTE,
                      path: '',
                      component: AiCatalogAgentsShow,
                    },
                  ],
                },
              ]),
          { path: '*', redirect: '/agents' },
        ],
      },
      ...(gon.features?.aiCatalogFlows || gon.features?.aiCatalogThirdPartyFlows
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
                  component: AiFlowsIndex,
                },
                ...(gon.features?.aiCatalogItemProjectCuration
                  ? [
                      {
                        name: AI_CATALOG_FLOWS_NEW_ROUTE,
                        path: 'new',
                        component: AiCatalogFlowsNew,
                        meta: {
                          text: s__('AICatalog|New flow'),
                        },
                      },
                      {
                        path: ':id(\\d+)',
                        component: AiCatalogFlow,
                        meta: {
                          useId: true,
                          defaultRoute: AI_CATALOG_FLOWS_SHOW_ROUTE,
                        },
                        children: [
                          {
                            name: AI_CATALOG_FLOWS_SHOW_ROUTE,
                            path: '',
                            component: AiCatalogFlowsShow,
                          },
                          {
                            name: AI_CATALOG_FLOWS_EDIT_ROUTE,
                            path: 'edit',
                            component: AiCatalogFlowsEdit,
                            meta: {
                              text: s__('AICatalog|Edit flow'),
                            },
                          },
                          {
                            name: AI_CATALOG_FLOWS_DUPLICATE_ROUTE,
                            path: 'duplicate',
                            component: AiCatalogFlowsDuplicate,
                            meta: {
                              text: s__('AICatalog|Duplicate flow'),
                            },
                          },
                        ],
                      },
                    ]
                  : [
                      {
                        path: ':id(\\d+)',
                        component: AiCatalogFlow,
                        meta: {
                          useId: true,
                        },
                        children: [
                          {
                            name: AI_CATALOG_FLOWS_SHOW_ROUTE,
                            path: '',
                            component: AiCatalogFlowsShow,
                          },
                        ],
                      },
                    ]),
                { path: '*', redirect: '/flows' },
              ],
            },
          ]
        : []),
      // /automate route is currently empty, so we can't redirect there
      { path: '*', redirect: '/agent-sessions' },
    ],
  });
};
