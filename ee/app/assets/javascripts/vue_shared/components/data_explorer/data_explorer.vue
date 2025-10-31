<script>
// This component is still under active development. Updates on the current progress
// can be found in https://gitlab.com/groups/gitlab-org/-/epics/19359
import EMPTY_CHART_SVG from '@gitlab/svgs/dist/illustrations/empty-state/empty-chart-md.svg?url';
import { GlFormTextarea, GlButton, GlCard, GlEmptyState, GlLink } from '@gitlab/ui';
import ModalCopyButton from '~/vue_shared/components/modal_copy_button.vue';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'DataExplorer',
  components: {
    GlFormTextarea,
    GlButton,
    GlCard,
    GlEmptyState,
    GlLink,
    ModalCopyButton,
  },
  glqlDocsLink: helpPagePath('user/glql/_index'),
  EMPTY_CHART_SVG,
  data() {
    return { query: '' };
  },
  computed: {
    hasQueryText() {
      return this.query.trim() !== '';
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-3">
    <div class="gl-relative">
      <gl-form-textarea
        v-model="query"
        :aria-label="s__('DataExplorer|Data query')"
        :placeholder="s__('DataExplorer|// TYPE YOUR QUERY HERE')"
        :no-resize="false"
        rows="16"
        textarea-classes="!gl-p-6 !gl-font-monospace"
      />
      <modal-copy-button
        v-if="hasQueryText"
        :title="s__('DataExplorer|Copy query')"
        :text="query"
        class="gl-absolute gl-right-6 gl-top-6 gl-z-1"
      />

      <gl-link :href="$options.glqlDocsLink" class="gl-absolute gl-bottom-6 gl-right-6 gl-z-1">{{
        s__('DataExplorer|What is GLQL?')
      }}</gl-link>
    </div>

    <div>
      <gl-button variant="confirm" icon="play" :disabled="!hasQueryText">{{
        s__('DataExplorer|Run query')
      }}</gl-button>
    </div>

    <gl-card>
      <!-- TODO: Add resolver.vue (https://gitlab.com/gitlab-org/gitlab/-/issues/570014) -->
      <gl-empty-state
        :title="s__('DataExplorer|Preview not available')"
        :description="s__('DataExplorer|Start by typing a GLQL query.')"
        :svg-path="$options.EMPTY_CHART_SVG"
      />
    </gl-card>
  </div>
</template>
