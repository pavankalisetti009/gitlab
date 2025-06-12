import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';

import AgentsPlatformApp from './agents_platform_app.vue';
import { createRouter } from './router';

export const initAgentsPlatformPage = (selector = '#js-duo-agents-platform-page') => {
  const el = document.querySelector(selector);
  if (!el) {
    return null;
  }

  const { dataset } = el;
  const { agentsPlatformBaseRoute } = dataset;

  Vue.use(VueApollo);

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  return new Vue({
    el,
    name: 'AgentsPlatformApp',
    router: createRouter(agentsPlatformBaseRoute),
    apolloProvider,
    render(h) {
      return h(AgentsPlatformApp);
    },
  });
};
