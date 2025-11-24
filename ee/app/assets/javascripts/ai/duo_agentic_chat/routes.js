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
];
