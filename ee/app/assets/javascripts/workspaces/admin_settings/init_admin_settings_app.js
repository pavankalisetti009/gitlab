import Vue from 'vue';
import WorkspacesAgentAvailabilityApp from './pages/app.vue';

const initWorkspacesAgentAvailabilityApp = () => {
  const el = document.getElementById('js-workspaces-agent-availability-settings-body');

  if (!el) return null;

  return new Vue({
    el,
    components: {
      WorkspacesAgentAvailabilityApp,
    },
    render(createElement) {
      return createElement(WorkspacesAgentAvailabilityApp);
    },
  });
};

export { initWorkspacesAgentAvailabilityApp };
