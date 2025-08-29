import Vue from 'vue';
import AIPanel from './components/ai_panel.vue';

export function initDuoPanel() {
  const el = document.getElementById('duo-chat-panel');

  if (!el) {
    return false;
  }

  return new Vue({
    el,
    render(createElement) {
      return createElement(AIPanel);
    },
  });
}
