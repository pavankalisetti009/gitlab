import Vue from 'vue';
import apolloProvider from 'ee/vue_shared/security_configuration/graphql/provider';
import App from './components/app.vue';

export default () => {
  const el = document.querySelector('#js-group-security-inventory');
  if (!el) {
    return null;
  }
  if (!el) {
    return null;
  }

  const { groupFullPath, groupName } = el.dataset;

  return new Vue({
    el,
    apolloProvider,
    provide: {
      groupFullPath,
      groupName,
    },
    render(createElement) {
      return createElement(App);
    },
  });
};
