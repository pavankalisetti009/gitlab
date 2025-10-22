// import { BASE_ROUTE, ADMIN_GROUPS_ROUTE_NAME, ADMIN_GROUPS_TABS } from './constants';

import { s__ } from '~/locale';
import NestedRouteApp from 'ee/ai/duo_agents_platform/nested_route_app.vue';
import AgentsPlatformShow from 'ee/ai/duo_agents_platform/pages/show/duo_agents_platform_show.vue';
import { getNamespaceIndexComponent } from 'ee/ai/duo_agents_platform/router/utils';

import {
  AGENTS_PLATFORM_INDEX_ROUTE,
  AGENTS_PLATFORM_SHOW_ROUTE,
} from 'ee/ai/duo_agents_platform/router/constants';
import DuoAgenticChat from './components/duo_agentic_chat.vue';

export default [
  {
    path: '/current',
    component: DuoAgenticChat,
    props: {
      mode: 'active',
    },
  },
  {
    path: '/chat',
    component: DuoAgenticChat,
  },
  {
    path: '/new',
    component: DuoAgenticChat,
    props: {
      mode: 'new',
    },
  },
  {
    path: '/history',
    component: DuoAgenticChat,
    props: {
      mode: 'history',
    },
  },
  {
    component: NestedRouteApp,
    path: '/sessions',
    meta: {
      text: s__('DuoAgentsPlatform|Sessions'),
    },
    children: [
      {
        name: AGENTS_PLATFORM_INDEX_ROUTE,
        path: '',
        component: getNamespaceIndexComponent('user'),
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
];
