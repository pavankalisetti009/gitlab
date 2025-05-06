<script>
import { GlButton, GlIcon, GlTooltip } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { createAlert } from '~/alert';
import updateAiFeatureSettings from '../graphql/mutations/update_ai_feature_setting.mutation.graphql';
import getAiFeatureSettingsQuery from '../graphql/queries/get_ai_feature_settings.query.graphql';
import { PROVIDERS } from '../constants';

export default {
  name: 'FeatureSettingsBatchAssignmentButton',
  components: {
    GlButton,
    GlIcon,
    GlTooltip,
  },
  props: {
    aiFeatureSettings: {
      type: Array,
      required: true,
    },
    currentFeatureSetting: {
      type: Object,
      required: true,
    },
  },
  computed: {
    isCurrentFeatureSettingUnassigned() {
      const providers = [PROVIDERS.SELF_HOSTED, PROVIDERS.DISABLED];

      return !providers.includes(this.currentFeatureSetting.provider);
    },
    isCurrentFeatureSettingDisabledOrUnassigned() {
      return (
        this.isCurrentFeatureSettingUnassigned ||
        this.currentFeatureSetting.provider === PROVIDERS.DISABLED
      );
    },
    errorMessage() {
      return sprintf(
        s__(
          'AdminSelfHostedModels|An error occurred while updating the %{mainFeature} sub-feature settings. Please try again.',
        ),
        { mainFeature: this.currentFeatureSetting.mainFeature },
      );
    },
    tooltipTitle() {
      return sprintf(s__('AdminSelfHostedModels|Apply to all %{mainFeature} sub-features'), {
        mainFeature: this.currentFeatureSetting.mainFeature,
      });
    },
    disabledTooltipTitle() {
      return sprintf(
        s__(
          'AdminSelfHostedModels|Assign a model to the %{subFeatureTitle} sub-feature before applying to all',
        ),
        {
          subFeatureTitle: this.currentFeatureSetting.title,
        },
      );
    },
    warningTooltipTitle() {
      return s__('AdminSelfHostedModels|Assign a model to enable this feature');
    },
  },
  methods: {
    updateCache(cache, { data: { aiFeatureSettingUpdate } }) {
      const previousData = cache.readQuery({
        query: getAiFeatureSettingsQuery,
      });

      if (!previousData) return;

      const updateData = aiFeatureSettingUpdate.aiFeatureSettings;
      const updatedFeatureSettingsMap = updateData.reduce((map, fs) => {
        return { ...map, [fs.feature]: fs };
      }, {});

      const updatedFeatureSettingsData = previousData.aiFeatureSettings.nodes.map(
        (node) => updatedFeatureSettingsMap[node.feature] || node,
      );

      cache.writeQuery({
        query: getAiFeatureSettingsQuery,
        data: {
          aiFeatureSettings: {
            __typename: 'AiFeatureSettingConnection',
            nodes: updatedFeatureSettingsData,
          },
        },
      });
    },
    async onClick() {
      this.$emit('update-batch-saving-state', true);

      try {
        const features = this.aiFeatureSettings.map((fs) => fs.feature.toUpperCase());
        const { provider, selfHostedModel } = this.currentFeatureSetting;

        const { data } = await this.$apollo.mutate({
          mutation: updateAiFeatureSettings,
          variables: {
            input: {
              features,
              provider: provider.toUpperCase(),
              aiSelfHostedModelId: provider === PROVIDERS.DISABLED ? null : selfHostedModel?.id,
            },
          },
          update: (cache, result) => this.updateCache(cache, result),
        });

        if (data) {
          const { errors, aiFeatureSettings } = data.aiFeatureSettingUpdate;

          if (errors.length > 0) {
            throw new Error(errors[0]);
          }

          this.$emit('update-feature-settings', aiFeatureSettings);
        }
      } catch (error) {
        createAlert({
          message: this.errorMessage,
          error,
          captureError: true,
        });
      } finally {
        this.$emit('update-batch-saving-state', false);
      }
    },
  },
};
</script>
<template>
  <div :class="{ 'gl-flex gl-w-full gl-justify-between': isCurrentFeatureSettingUnassigned }">
    <div v-if="isCurrentFeatureSettingUnassigned" ref="unAssignedFeatureWarning">
      <div
        class="align-items-center gl-flex gl-h-7 gl-w-7 gl-justify-center gl-rounded-base gl-bg-orange-50"
      >
        <gl-icon
          data-testid="warning-icon"
          :aria-label="warningTooltipTitle"
          name="warning"
          variant="warning"
          :size="16"
        />
      </div>
      <gl-tooltip
        data-testid="unassigned-feature-tooltip"
        :target="() => $refs.unAssignedFeatureWarning"
        :title="warningTooltipTitle"
      />
    </div>
    <div ref="batchUpdateButton">
      <gl-button
        data-testid="model-batch-assignment-button"
        :aria-label="tooltipTitle"
        category="primary"
        icon="duplicate"
        :disabled="isCurrentFeatureSettingDisabledOrUnassigned"
        @click="onClick"
      />
      <gl-tooltip
        data-testid="model-batch-assignment-tooltip"
        :target="() => $refs.batchUpdateButton"
        :title="isCurrentFeatureSettingDisabledOrUnassigned ? disabledTooltipTitle : tooltipTitle"
      />
    </div>
  </div>
</template>
