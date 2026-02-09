import { makeVar } from '@apollo/client/core';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import Cookies from '~/lib/utils/cookies';
import { duoChatGlobalState } from '~/super_sidebar/constants';

export const ACTIVE_TAB_KEY = 'ai_panel_active_tab';
export const activeTab = makeVar();

export const setAiPanelTab = (tab) => {
  if (tab) {
    Cookies.set(ACTIVE_TAB_KEY, tab);
  } else {
    Cookies.remove(ACTIVE_TAB_KEY);
  }

  duoChatGlobalState.activeTab = tab || undefined;
  return activeTab(tab || undefined);
};

export const cacheConfig = {
  typePolicies: {
    Query: {
      fields: {
        activeTab: {
          read() {
            return activeTab();
          },
        },
      },
    },
  },
};

export const createApolloProvider = ({ autoExpand = false } = {}) => {
  const savedTab = Cookies.get(ACTIVE_TAB_KEY);

  if (autoExpand && !savedTab) {
    activeTab('chat');
  } else {
    activeTab(savedTab);
  }

  const defaultClient = createDefaultClient(
    {},
    {
      cacheConfig,
    },
  );

  return new VueApollo({ defaultClient });
};
