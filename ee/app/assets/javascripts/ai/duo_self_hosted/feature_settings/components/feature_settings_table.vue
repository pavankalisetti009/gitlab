<script>
import { GlExperimentBadge } from '@gitlab/ui';
import BaseFeatureSettingsTable from 'ee/ai/shared/feature_settings/base_feature_settings_table.vue';
import ModelHeader from 'ee/ai/shared/feature_settings/model_header.vue';
import { s__ } from '~/locale';
import {
  FEATURE_SETTINGS_FIXED_LOADER_WIDTH,
  FEATURE_SETTINGS_VARIABLE_LOADER_WIDTHS,
} from 'ee/ai/shared/feature_settings/constants';
import { RELEASE_STATES } from 'ee/ai/duo_self_hosted/constants';
import ModelSelector from './model_selector.vue';
import DuoSelfHostedBatchSettingsUpdater from './batch_settings_updater.vue';

export default {
  name: 'FeatureSettingsTable',
  components: {
    BaseFeatureSettingsTable,
    GlExperimentBadge,
    DuoSelfHostedBatchSettingsUpdater,
    ModelSelector,
    ModelHeader,
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
    getBadgeType(releaseState) {
      if (releaseState === RELEASE_STATES.BETA) {
        return 'beta';
      }
      if (releaseState === RELEASE_STATES.EXPERIMENT) {
        return 'experiment';
      }

      return '';
    },
    updateBatchSavingState(state) {
      this.batchUpdateIsSaving = state;
    },
  },
  fields: [
    {
      key: 'sub_feature',
      label: s__('AdminAIPoweredFeatures|Features'),
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
      thClass: 'gl-hidden gl-w-1/3',
    },
  ],
};
</script>
<template>
  <base-feature-settings-table
    :fields="$options.fields"
    :items="featureSettings"
    :is-loading="isLoading"
  >
    <template #head(model_name)="{ label }">
      <model-header :label="label">
        <template #tooltip-text>
          <span data-testid="model-header-tooltip">
            {{ s__('AdminAIPoweredFeatures|Select the model for the feature') }}
          </span>
        </template>
      </model-header>
    </template>
    <template #cell(sub_feature)="{ item }">
      <gl-experiment-badge
        v-if="getBadgeType(item.releaseState)"
        class="gl-ml-0 gl-mr-3"
        data-testid="feature-badge"
        :type="getBadgeType(item.releaseState)"
      />
      <span>{{ item.title }}</span>
    </template>
    <template #cell(model_name)="{ item }">
      <model-selector :ai-feature-setting="item" :batch-update-is-saving="batchUpdateIsSaving" />
    </template>
    <template #cell(batch_model_update)="{ item }">
      <duo-self-hosted-batch-settings-updater
        v-if="!isLoading && featureSettings.length > 1"
        class="gl-float-right"
        :ai-feature-settings="featureSettings"
        :selected-feature-setting="item"
        @update-batch-saving-state="updateBatchSavingState"
      />
    </template>
  </base-feature-settings-table>
</template>
