import Vue from 'vue';
import VueRouter from 'vue-router';
import { s__ } from '~/locale';
import { AI_CATALOG_FLOWS_ROUTE } from 'ee/ai/catalog/router/constants';
import NestedRouteApp from '../nested_route_app.vue';
import AgentsPlatformShow from '../pages/show/duo_agents_platform_show.vue';
import AgentsPlatformNew from '../pages/new/duo_agents_platform_new.vue';
import FlowTriggersIndex from '../pages/flow_triggers/index/flow_triggers_index.vue';
import FlowTriggersNew from '../pages/flow_triggers/flow_triggers_new.vue';
import FlowTriggersEdit from '../pages/flow_triggers/flow_triggers_edit.vue';
import AiFlows from '../pages/flows/ai_flows.vue';
import {
  AGENTS_PLATFORM_INDEX_ROUTE,
  AGENTS_PLATFORM_NEW_ROUTE,
  AGENTS_PLATFORM_SHOW_ROUTE,
  WORKFLOW_END_PAGE_LINK,
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
          text: s__('DuoAgentsPlatform|Agent sessions'),
        },
        children: [
          {
            name: AGENTS_PLATFORM_INDEX_ROUTE,
            path: '',
            component: getNamespaceIndexComponent(namespace),
          },
          {
            name: AGENTS_PLATFORM_NEW_ROUTE,
            path: 'new',
            component: AgentsPlatformNew,
            meta: {
              text: s__('DuoAgentsPlatform|New'),
            },
          },
          // TODO: Remove when https://gitlab.com/gitlab-org/duo-ui/-/issues/83 is done
          // Maps the workflow_end message type to the platform new page
          {
            name: WORKFLOW_END_PAGE_LINK,
            path: 'new',
            component: AgentsPlatformNew,
            meta: {
              text: s__('DuoAgentsPlatform|New'),
            },
          },
          // Used as hardcoded path in
          // https://gitlab.com/gitlab-org/gitlab/-/blob/e9b59c5de32c6ce4e14665681afbf95cf001c044/ee/app/assets/javascripts/ai/components/duo_workflow_action.vue#L76.
          {
            name: AGENTS_PLATFORM_SHOW_ROUTE,
            path: ':id(\\d+)',
            component: AgentsPlatformShow,
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
              text: s__('DuoAgentsPlatform|New'),
            },
          },
          {
            path: ':id(\\d+)/edit',
            component: FlowTriggersEdit,
            name: FLOW_TRIGGERS_EDIT_ROUTE,
            meta: {
              text: s__('AICatalog|Edit flow'),
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
        path: '/flows',
        meta: {
          text: s__('AICatalog|Flows'),
        },
        children: [
          {
            name: AI_CATALOG_FLOWS_ROUTE,
            path: '',
            component: AiFlows,
          },
        ],
      },
      // /automate route is currently empty, so we can't redirect there
      { path: '*', redirect: '/agent-sessions' },
    ],
  });
};
