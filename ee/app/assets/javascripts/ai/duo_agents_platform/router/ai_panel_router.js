import Vue from 'vue';
import VueRouter from 'vue-router';
import { s__ } from '~/locale';
import NestedRouteApp from '~/vue_shared/spa/components/router_view.vue';
import { eventHub, SHOW_SESSION } from 'ee/ai/events/panel';
import AgentsPlatformShow from '../pages/show/duo_agents_platform_show.vue';
import {
  getStorageKey,
  restoreLastRoute,
  saveRouteState,
  setupNavigationGuards,
  trackTabRoutes,
} from '../utils/navigation_state';
import { AGENTS_PLATFORM_INDEX_ROUTE, AGENTS_PLATFORM_SHOW_ROUTE } from './constants';
import { getNamespaceIndexComponent } from './utils';

Vue.use(VueRouter);

const SAVED_ROUTE_CONTEXT = 'side_panel';

const setupRouterPanelEvents = (router) => {
  eventHub.$on(SHOW_SESSION, async ({ id }) => {
    await router.push({ name: AGENTS_PLATFORM_SHOW_ROUTE, params: { id } });
  });
};

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
    context: SAVED_ROUTE_CONTEXT,
  });

  // Track routes for AI panel tab navigation
  router.beforeEach((to, _from, next) => {
    trackTabRoutes(to);
    next();
  });

  setupRouterPanelEvents(router);

  // Use nextTick to ensure router is properly initialized before navigation
  // This is needed for abstract routers because it needs a base route
  Vue.nextTick(() => {
    // Try to restore the last visited session from side panel context, otherwise go to index
    restoreLastRoute(router, { context: SAVED_ROUTE_CONTEXT });
  });

  return router;
};
