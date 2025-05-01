import Vue from 'vue';
import GetStarted from '../components/get_started.vue';

function initGetStarted() {
  const el = document.getElementById('js-get-started-app');

  if (!el) return null;

  return new Vue({
    el,
    render(createElement) {
      return createElement(GetStarted);
    },
  });
}

initGetStarted();
