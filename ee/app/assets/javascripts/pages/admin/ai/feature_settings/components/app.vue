<script>
import { GlSkeletonLoader } from '@gitlab/ui';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import getAiFeatureSettingsQuery from '../graphql/queries/get_ai_feature_settings.query.graphql';
import AiFeatureSettingsTable from './feature_settings_table.vue';

export default {
  name: 'FeatureSettingsApp',
  components: {
    GlSkeletonLoader,
    AiFeatureSettingsTable,
  },
  props: {
    newSelfHostedModelPath: {
      type: String,
      required: true,
    },
  },
  i18n: {
    title: s__('AdminAIPoweredFeatures|AI-powered features'),
    description: s__(
      'AdminAIPoweredFeatures|Features that can be enabled, disabled, or linked to a cloud-based or self-hosted model.',
    ),
    errorMessage: s__(
      'AdminAIPoweredFeatures|An error occurred while loading the AI feature settings. Please try again.',
    ),
  },
  data() {
    return {
      aiFeatureSettings: [],
    };
  },
  apollo: {
    aiFeatureSettings: {
      query: getAiFeatureSettingsQuery,
      update(data) {
        return data?.aiFeatureSettings?.nodes || [];
      },
      error(error) {
        createAlert({ message: this.$options.i18n.errorMessage, error, captureError: true });
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo?.queries?.aiFeatureSettings?.loading;
    },
  },
};
</script>
<template>
  <div>
    <section>
      <h1 class="page-title gl-text-size-h-display">
        {{ $options.i18n.title }}
      </h1>
      <div class="gl-items-top gl-flex gl-justify-between">
        <p>{{ $options.i18n.description }}</p>
      </div>
    </section>
    <gl-skeleton-loader v-if="isLoading" />
    <ai-feature-settings-table
      v-else
      :ai-feature-settings="aiFeatureSettings"
      :new-self-hosted-model-path="newSelfHostedModelPath"
    />
  </div>
</template>
