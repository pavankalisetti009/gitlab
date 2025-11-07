import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import { __ } from '~/locale';
import { createRouter } from 'ee/ai/duo_agents_platform/router/ai_panel_router';
import DuoAgenticChat from 'ee/ai/duo_agentic_chat/components/duo_agentic_chat.vue';
import DuoChat from 'ee/ai/tanuki_bot/components/duo_chat.vue';
import { activeWorkItemIds } from '~/work_items/utils';
import store from './tanuki_bot/store';
import AIPanel from './components/ai_panel.vue';

export function initDuoPanel() {
  const el = document.getElementById('duo-chat-panel');

  if (!el) {
    return false;
  }

  const {
    userId,
    projectId,
    namespaceId,
    rootNamespaceId,
    resourceId,
    metadata,
    userModelSelectionEnabled,
    agenticAvailable,
    agenticUnavailableMessage,
    chatTitle,
    chatDisabledReason,
  } = el.dataset;

  const router = createRouter('/', 'user');
  Vue.use(VueApollo);

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  // Configure chat-specific values in a single configuration object
  const chatConfiguration = {
    agenticComponent: parseBoolean(agenticAvailable)
      ? DuoAgenticChat
      : agenticUnavailableMessage || __('Chat is not available.'),
    classicComponent: DuoChat,
    agenticTitle: chatTitle || __('GitLab Duo Agentic Chat'),
    classicTitle: __('GitLab Duo Chat'),
    defaultProps: {
      isEmbedded: true,
      userId,
      projectId,
      namespaceId,
      rootNamespaceId,
      resourceId,
      metadata,
      userModelSelectionEnabled: parseBoolean(userModelSelectionEnabled),
      agenticAvailable: parseBoolean(agenticAvailable),
      chatTitle,
    },
  };

  return new Vue({
    el,
    name: 'DuoPanel',
    store: store(),
    router,
    apolloProvider,
    provide: {
      isSidePanelView: true,
      // Inject chat configuration directly to components that need it
      chatConfiguration,
    },
    render(createElement) {
      const latestActiveWorkItemId = activeWorkItemIds.value[activeWorkItemIds.value.length - 1];
      return createElement(AIPanel, {
        props: {
          name: 'AiPanel',
          userId,
          projectId,
          namespaceId,
          rootNamespaceId,
          resourceId: latestActiveWorkItemId ?? resourceId,
          metadata,
          userModelSelectionEnabled: parseBoolean(userModelSelectionEnabled),
          chatDisabledReason,
        },
      });
    },
  });
}
