<script>
import { GlSkeletonLoader } from '@gitlab/ui';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import FeatureSettingsTable from '../feature_settings/components/feature_settings_table.vue';
import getAiFeatureSettingsQuery from '../feature_settings/graphql/queries/get_ai_feature_settings.query.graphql';

export default {
  name: 'AiFeatureSettingsPage',
  components: {
    FeatureSettingsTable,
    GlSkeletonLoader,
  },
  i18n: {
    errorMessage: s__(
      'AdminAIPoweredFeatures|An error occurred while loading the AI feature settings. Please try again.',
    ),
  },
  data() {
    return {
      aiFeatureSettings: [],
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.loading;
    },
  },
  apollo: {
    aiFeatureSettings: {
      query: getAiFeatureSettingsQuery,
      update(data) {
        return data.aiFeatureSettings?.nodes || [];
      },
      error(error) {
        createAlert({
          message: this.$options.i18n.errorMessage,
          error,
          captureError: true,
        });
      },
    },
  },
};
</script>

<template>
  <div>
    <div v-if="isLoading" class="gl-pt-5">
      <gl-skeleton-loader />
    </div>
    <div v-else>
      <!-- TODO: Set up router and remove hard-coded paths -->
      <feature-settings-table
        :ai-feature-settings="aiFeatureSettings"
        new-self-hosted-model-path="/admin/ai/self_hosted_models/new"
      />
    </div>
  </div>
</template>
