import Vue from 'vue';
import VueRouter from 'vue-router';
import { s__ } from '~/locale';
import NestedRouteApp from '../nested_route_app.vue';
import AgentsPlatformShow from '../pages/show/duo_agents_platform_show.vue';

import {
  getStorageKey,
  restoreLastRoute,
  saveRouteState,
  setupNavigationGuards,
} from '../utils/navigation_state';
import { AGENTS_PLATFORM_INDEX_ROUTE, AGENTS_PLATFORM_SHOW_ROUTE } from './constants';
import { getNamespaceIndexComponent } from './utils';

Vue.use(VueRouter);

const SAVED_ROUTE_CONTEXT = 'side_panel';

export const createRouter = (base, namespace) => {
  const router = new VueRouter({
    base,
    mode: 'abstract',
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
            beforeEnter(to, _from, next) {
              saveRouteState(to, getStorageKey(SAVED_ROUTE_CONTEXT));
              next();
            },
          },
        ],
      },
    ],
  });

  // Set up navigation guards for session state persistence (enabled for side panels)
  setupNavigationGuards({
    router,
    enableStatePersistence: true,
  });

  // Use nextTick to ensure router is properly initialized before navigation
  // This is needed for abstract routers because it needs a base route
  Vue.nextTick(() => {
    // Try to restore the last visited session from side panel context, otherwise go to index
    restoreLastRoute(router, { ontext: SAVED_ROUTE_CONTEXT });
  });

  return router;
};
