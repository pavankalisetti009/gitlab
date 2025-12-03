import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import VisualCiEditorApp from './components/visual_ci_editor_app.vue';

Vue.use(VueApollo);

export const initVisualCiEditor = () => {
  const el = document.querySelector('#js-visual-ci-editor');

  if (!el) {
    return false;
  }

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  return new Vue({
    el,
    name: 'VisualCiEditorRoot',
    apolloProvider,
    render(createElement) {
      return createElement(VisualCiEditorApp);
    },
  });
};
