import Vue from 'vue';
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
    name: 'SecurityInventory',
    render(createElement) {
      return createElement(App, {
        provide: {
          groupFullPath,
          groupName,
        },
      });
    },
  });
};
