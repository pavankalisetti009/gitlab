<script>
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { logError } from '~/lib/logger';

export default {
  name: 'VisualCIEditorApp',
  mixins: [glFeatureFlagsMixin()],
  mounted() {
    this.loadVisualCiEditor();
  },
  methods: {
    async loadVisualCiEditor() {
      if (this.glFeatures.visualCiEditor) {
        try {
          await import('fe_islands/visual_ci_editor/dist/main');
        } catch (err) {
          logError('Failed to load frontend islands visual_ci_editor module', err);
        }
      }
    },
  },
};
</script>
<template>
  <div>
    <fe-island-visual-ci-editor />
  </div>
</template>
