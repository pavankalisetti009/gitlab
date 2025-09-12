import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { createRouter } from 'ee/ai/duo_agents_platform/router/ai_panel_router';
import AIPanel from './components/ai_panel.vue';

export function initDuoPanel() {
  const el = document.getElementById('duo-chat-panel');

  if (!el) {
    return false;
  }

  const router = createRouter('/', 'user');
  Vue.use(VueApollo);

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  return new Vue({
    el,
    router,
    apolloProvider,
    provide: {
      duoAgentsInvokePath: '',
      emptyStateIllustrationPath: '',
      isSidePanelView: true,
    },
    render(createElement) {
      return createElement(AIPanel, {
        props: {
          name: 'AiPanel',
        },
      });
    },
  });
}
