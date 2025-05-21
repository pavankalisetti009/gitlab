<script>
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import FeatureSettingsTable from 'ee/ai/shared/feature_settings/feature_settings_table.vue';
import aiNamespaceFeatureSettingsQuery from './graphql/get_ai_namepace_feature_settings.query.graphql';

export default {
  name: 'ModelSelectionApp',
  components: {
    FeatureSettingsTable,
    PageHeading,
  },
  inject: ['groupId'],
  data() {
    return {
      aiNamespaceFeatureSettings: [],
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiNamespaceFeatureSettings.loading;
    },
  },
  apollo: {
    aiNamespaceFeatureSettings: {
      query: aiNamespaceFeatureSettingsQuery,
      variables() {
        return { groupId: this.groupId };
      },
      update(data) {
        return data.aiModelSelectionNamespaceSettings?.nodes || [];
      },
      error(error) {
        createAlert({
          message: s__(
            'ModelSelection|An error occurred while loading the AI feature settings. Please try again.',
          ),
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
    <page-heading>
      <template #heading>
        <div data-testid="model-selection-title">
          {{ s__('ModelSelection|Model Selection') }}
        </div>
      </template>
      <template #description>{{
        s__(
          'ModelSelection|Manage GitLab Duo by configuring and assigning models to AI-native features.',
        )
      }}</template>
    </page-heading>
    <feature-settings-table
      :feature-settings="aiNamespaceFeatureSettings"
      :is-loading="isLoading"
    />
  </div>
</template>
