import Vue from 'vue';
import App from './components/app.vue';

export default function init() {
  const el = document.querySelector('#js-secret-detection-configuration');

  if (!el) {
    return undefined;
  }

  const { projectFullPath } = el.dataset;

  return new Vue({
    el,
    provide: {
      projectFullPath,
    },
    render(createElement) {
      return createElement(App);
    },
  });
}
