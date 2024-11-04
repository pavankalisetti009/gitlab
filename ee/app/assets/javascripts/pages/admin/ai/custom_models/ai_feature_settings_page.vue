<script>
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import FeatureSettingsTable from '../feature_settings/components/feature_settings_table.vue';
import getAiFeatureSettingsQuery from '../feature_settings/graphql/queries/get_ai_feature_settings.query.graphql';

export default {
  name: 'AiFeatureSettingsPage',
  components: {
    FeatureSettingsTable,
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
  <feature-settings-table :ai-feature-settings="aiFeatureSettings" :loading="isLoading" />
</template>
