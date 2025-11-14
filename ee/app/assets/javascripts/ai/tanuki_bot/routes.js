// import { BASE_ROUTE, ADMIN_GROUPS_ROUTE_NAME, ADMIN_GROUPS_TABS } from './constants';

import DuoChat from './components/duo_chat.vue';

export default [
  {
    path: '/chat',
    component: DuoChat,
    props: {
      mode: 'chat',
    },
  },
  {
    path: '/new',
    component: DuoChat,
    props: {
      mode: 'new',
    },
  },
  {
    path: '/history',
    component: DuoChat,
    props: {
      mode: 'history',
    },
  },
];
