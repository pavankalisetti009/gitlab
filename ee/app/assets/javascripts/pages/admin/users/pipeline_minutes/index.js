import { GlToast } from '@gitlab/ui';
import Vue from 'vue';
import { CONTEXT_TYPE } from '~/members/constants';
import ResetButton from './reset_button.vue';

Vue.use(GlToast);

export function pipelineMinutes() {
  const el = document.getElementById('js-pipeline-minutes-vue');

  if (el) {
    const { resetMinutesPath, contextType } = el.dataset;

    // eslint-disable-next-line no-new
    new Vue({
      el,
      name: 'ResetButtonRoot',
      provide: {
        resetMinutesPath,
        contextType: contextType || CONTEXT_TYPE.GROUP,
      },
      render(createElement) {
        return createElement(ResetButton);
      },
    });
  }
}
