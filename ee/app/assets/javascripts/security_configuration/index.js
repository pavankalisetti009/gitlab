import Vue from 'vue';
import SecurityConfigurationApp from './components/app.vue';

export const initSecurityConfiguration = (el) => {
  if (!el) {
    return null;
  }

  const { groupFullPath } = el.dataset;

  return new Vue({
    el,
    name: 'SecurityConfigurationRoot',
    provide: {
      groupFullPath,
    },
    render(createElement) {
      return createElement(SecurityConfigurationApp);
    },
  });
};
