<script>
import PageHeading from '~/vue_shared/components/page_heading.vue';
import FeatureSettingsTable from 'ee/ai/shared/feature_settings/feature_settings_table.vue';
import { mockFeatureSettings } from '../../../../../spec/frontend/ai/shared/feature_settings/mock_data';

export default {
  name: 'ModelSelectionApp',
  components: {
    FeatureSettingsTable,
    PageHeading,
  },
  data() {
    return {
      // Temporarily return mock data until the gql query is implemented
      aiFeatureSettings: mockFeatureSettings,
      isLoading: false,
    };
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
    <feature-settings-table :feature-settings="aiFeatureSettings" :is-loading="isLoading" />
  </div>
</template>
