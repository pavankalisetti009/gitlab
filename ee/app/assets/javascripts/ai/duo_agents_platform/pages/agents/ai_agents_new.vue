<script>
import { s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import PageHeading from '~/vue_shared/components/page_heading.vue';

export default {
  name: 'AiAgentsNew',
  components: {
    PageHeading,
  },
  mixins: [glFeatureFlagsMixin()],
  computed: {
    descriptionText() {
      return this.glFeatures.aiCatalogFlows
        ? s__('AICatalog|Use agents in flows and with GitLab Duo Chat.')
        : s__(
            'AICatalog|Use agents with GitLab Duo Chat to complete tasks and answer complex questions.',
          );
    },
  },
};
</script>

<template>
  <div>
    <page-heading :heading="s__('AICatalog|New agent')">
      <template #description>
        {{ descriptionText }}
      </template>
    </page-heading>
  </div>
</template>
