import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import store from '../tanuki_bot/store';
import DuoAgenticChatApp from './components/app.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initDuoAgenticChat = () => {
  const el = document.getElementById('js-duo-agentic-chat-app');

  if (!el) {
    return false;
  }

  const toggleEls = document.querySelectorAll('.js-duo-agentic-chat-toggle');
  if (toggleEls.length) {
    toggleEls.forEach((toggleEl) => {
      toggleEl.addEventListener('click', () => {
        duoChatGlobalState.isAgenticChatShown = !duoChatGlobalState.isAgenticChatShown;
      });
    });
  }

  const { projectId, resourceId } = el.dataset;

  return new Vue({
    el,
    store: store(),
    apolloProvider,
    render(createElement) {
      return createElement(DuoAgenticChatApp, {
        props: {
          projectId,
          resourceId,
        },
      });
    },
  });
};
