import Vue from 'vue';
import VueRouter from 'vue-router';
import AgentsPlatformIndex from '../pages/index/agents_platform_index.vue';
import { AGENTS_PLATFORM_INDEX_ROUTE } from './constants';

Vue.use(VueRouter);

export const createRouter = (base) => {
  return new VueRouter({
    base,
    mode: 'history',
    routes: [
      {
        name: AGENTS_PLATFORM_INDEX_ROUTE,
        path: '',
        component: AgentsPlatformIndex,
      },
    ],
  });
};
