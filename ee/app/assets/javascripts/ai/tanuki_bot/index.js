import Vue from 'vue';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import createDefaultClient from '~/lib/graphql';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import { getCookie } from '~/lib/utils/common_utils';
import { DUO_AGENTIC_MODE_COOKIE } from 'ee/ai/tanuki_bot/constants';
import DuoChatLayoutApp from './components/app.vue';
import store from './store';
import routes from './routes';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const createRouter = () => {
  const router = new VueRouter({
    routes,
    mode: 'abstract',
  });

  return router;
};

export const initTanukiBotChatDrawer = () => {
  const el = document.getElementById('js-tanuki-bot-chat-app');

  if (!el) {
    return false;
  }

  Vue.use(VueRouter);

  const { userId, resourceId, projectId, chatTitle, rootNamespaceId, agenticAvailable } =
    el.dataset;

  const toggleEls = document.querySelectorAll('.js-tanuki-bot-chat-toggle');
  if (toggleEls.length) {
    toggleEls.forEach((toggleEl) => {
      toggleEl.addEventListener('click', () => {
        if (getCookie(DUO_AGENTIC_MODE_COOKIE) === 'true' && agenticAvailable === 'true') {
          duoChatGlobalState.isAgenticChatShown = !duoChatGlobalState.isAgenticChatShown;
          duoChatGlobalState.isShown = false;
        } else {
          duoChatGlobalState.isShown = !duoChatGlobalState.isShown;
          duoChatGlobalState.isAgenticChatShown = false;
        }
      });
    });
  }

  return new Vue({
    el,
    store: store(),
    router: createRouter(),
    apolloProvider,
    render(createElement) {
      return createElement(DuoChatLayoutApp, {
        props: {
          userId,
          resourceId,
          projectId,
          chatTitle,
          rootNamespaceId,
          agenticAvailable: JSON.parse(agenticAvailable),
        },
      });
    },
  });
};
