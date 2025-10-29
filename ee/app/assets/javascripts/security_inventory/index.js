import Vue from 'vue';
import { parseBoolean } from '~/lib/utils/common_utils';
import apolloProvider from './graphql/provider';
import App from './components/app.vue';

export default () => {
  const el = document.querySelector('#js-group-security-inventory');
  if (!el) {
    return null;
  }
  if (!el) {
    return null;
  }

  const {
    groupFullPath,
    groupId,
    groupName,
    canManageAttributes,
    canReadAttributes,
    groupManageAttributesPath,
    newProjectPath,
  } = el.dataset;

  return new Vue({
    el,
    apolloProvider,
    provide: {
      groupFullPath,
      groupId,
      groupName,
      canManageAttributes: parseBoolean(canManageAttributes),
      canReadAttributes: parseBoolean(canReadAttributes),
      groupManageAttributesPath,
      newProjectPath,
    },
    render(createElement) {
      return createElement(App);
    },
  });
};
