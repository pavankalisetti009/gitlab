<script>
import { s__ } from '~/locale';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import BaseFeatureSettingsTable from 'ee/ai/shared/feature_settings/base_feature_settings_table.vue';
import ModelHeader from 'ee/ai/shared/feature_settings/model_header.vue';
import {
  FEATURE_SETTINGS_FIXED_LOADER_WIDTH,
  FEATURE_SETTINGS_VARIABLE_LOADER_WIDTHS,
} from 'ee/ai/shared/feature_settings/constants';

import ModelSelector from './model_selector.vue';
import ModelSelectionBatchSettingsUpdater from './batch_settings_updater.vue';

export default {
  name: 'ModelSelectionFeatureSettingsTable',
  components: {
    BaseFeatureSettingsTable,
    ModelSelector,
    ModelSelectionBatchSettingsUpdater,
    ModelHeader,
    HelpPageLink,
  },
  props: {
    featureSettings: {
      type: Array,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      batchUpdateIsSaving: false,
    };
  },
  methods: {
    updateBatchSavingState(state) {
      this.batchUpdateIsSaving = state;
    },
  },
  fields: [
    {
      key: 'sub_feature',
      label: s__('AdminAIPoweredFeatures|Feature'),
      thClass: 'gl-w-1/3',
      loaderWidths: FEATURE_SETTINGS_VARIABLE_LOADER_WIDTHS,
    },
    {
      key: 'model_name',
      label: s__('AdminAIPoweredFeatures|Model'),
      thClass: 'gl-w-1/3',
      loaderWidths: [FEATURE_SETTINGS_FIXED_LOADER_WIDTH],
    },

    {
      key: 'batch_model_update',
      label: s__('AdminAIPoweredFeatures|Apply to all sub-features'),
      thClass: 'gl-sr-only gl-w-1/3',
    },
  ],
};
</script>
<template>
  <base-feature-settings-table
    :items="featureSettings"
    :is-loading="isLoading"
    :fields="$options.fields"
  >
    <template #head(model_name)="{ label }">
      <model-header :label="label">
        <template #tooltip-text>
          <span data-testid="model-header-tooltip">
            {{
              s__(
                'AdminAIPoweredFeatures|Select a model version for full control of your configuration, or GitLab Default for GitLab to manage the selection.',
              )
            }}
            <help-page-link
              class="gl-text-blue-500"
              href="user/gitlab_duo/model_selection"
              target="_blank"
              >{{ __('Learn more.') }}
            </help-page-link>
          </span>
        </template>
      </model-header>
    </template>
    <template #cell(sub_feature)="{ item }">
      {{ item.title }}
    </template>
    <template #cell(model_name)="{ item }">
      <model-selector :ai-feature-setting="item" :batch-update-is-saving="batchUpdateIsSaving" />
    </template>
    <template #cell(batch_model_update)="{ item }">
      <model-selection-batch-settings-updater
        v-if="!isLoading && featureSettings.length > 1"
        class="gl-float-right"
        :ai-feature-settings="featureSettings"
        :selected-feature-setting="item"
        @update-batch-saving-state="updateBatchSavingState"
      />
    </template>
  </base-feature-settings-table>
</template>
