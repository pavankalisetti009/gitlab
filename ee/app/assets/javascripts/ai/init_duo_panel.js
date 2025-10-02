import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import { createRouter } from 'ee/ai/duo_agents_platform/router/ai_panel_router';
import store from './tanuki_bot/store';
import AIPanel from './components/ai_panel.vue';

export function initDuoPanel() {
  const el = document.getElementById('duo-chat-panel');

  if (!el) {
    return false;
  }

  const {
    projectId,
    namespaceId,
    rootNamespaceId,
    resourceId,
    metadata,
    userModelSelectionEnabled,
  } = el.dataset;

  const router = createRouter('/', 'user');
  Vue.use(VueApollo);

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  return new Vue({
    el,
    store: store(),
    router,
    apolloProvider,
    provide: {
      isSidePanelView: true,
    },
    render(createElement) {
      return createElement(AIPanel, {
        props: {
          name: 'AiPanel',
          projectId,
          namespaceId,
          rootNamespaceId,
          resourceId,
          metadata,
          userModelSelectionEnabled: parseBoolean(userModelSelectionEnabled),
        },
      });
    },
  });
}
