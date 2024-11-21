<script>
import { GlCollapsibleListbox, GlButton } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { createAlert } from '~/alert';
import updateAiFeatureSetting from '../graphql/mutations/update_ai_feature_setting.mutation.graphql';
import getAiFeatureSettingsQuery from '../graphql/queries/get_ai_feature_settings.query.graphql';
import getSelfHostedModelsQuery from '../../self_hosted_models/graphql/queries/get_self_hosted_models.query.graphql';

const PROVIDERS = {
  DISABLED: 'disabled',
  VENDORED: 'vendored',
  SELF_HOSTED: 'self_hosted',
};

const FEATURE_DISABLED = 'DISABLED';

export default {
  name: 'ModelSelectDropdown',
  components: {
    GlCollapsibleListbox,
    GlButton,
  },
  inject: ['newSelfHostedModelPath'],
  props: {
    aiFeatureSetting: {
      type: Object,
      required: true,
    },
  },
  i18n: {
    defaultErrorMessage: s__(
      'AdminSelfHostedModels|An error occurred while updating the sefl-hosted model, please try again.',
    ),
    successMessage: s__('AdminSelfHostedModels|Successfully updated %{mainFeature} / %{title}'),
  },
  data() {
    const { provider, selfHostedModel, validModels } = this.aiFeatureSetting;

    const selectedOption = provider === PROVIDERS.DISABLED ? FEATURE_DISABLED : selfHostedModel?.id;

    return {
      provider,
      selfHostedModelId: selfHostedModel?.id,
      compatibleModels: validModels?.nodes,
      selectedOption,
      isSaving: false,
    };
  },
  computed: {
    dropdownItems() {
      const modelOptions = this.compatibleModels.map((model) => ({
        value: model.id,
        text: `${model.name} (${model.model})`,
      }));

      // Add an option to disable the feature
      const disableOption = {
        value: FEATURE_DISABLED,
        text: s__('AdminAIPoweredFeatures|Disabled'),
      };

      return [...modelOptions, disableOption];
    },
    selectedModel() {
      return this.compatibleModels.find((m) => m.id === this.selfHostedModelId);
    },
    dropdownToggleText() {
      if (this.provider === PROVIDERS.DISABLED) {
        return s__('AdminAIPoweredFeatures|Disabled');
      }
      if (this.selectedModel) {
        return `${this.selectedModel?.name} (${this.selectedModel?.model})`;
      }

      return s__('AdminAIPoweredFeatures|Select a self-hosted model');
    },
  },
  methods: {
    async onSelect(option) {
      this.isSaving = true;

      try {
        const selectedOption = {
          option,
          provider: option === FEATURE_DISABLED ? PROVIDERS.DISABLED : PROVIDERS.SELF_HOSTED,
          selfHostedModelId: option === FEATURE_DISABLED ? null : option,
        };

        const { data } = await this.$apollo.mutate({
          mutation: updateAiFeatureSetting,
          variables: {
            input: {
              feature: this.aiFeatureSetting.feature.toUpperCase(),
              provider: selectedOption.provider.toUpperCase(),
              aiSelfHostedModelId: selectedOption.selfHostedModelId,
            },
          },
          refetchQueries: [
            { query: getSelfHostedModelsQuery },
            { query: getAiFeatureSettingsQuery },
          ],
        });

        if (data) {
          const { errors } = data.aiFeatureSettingUpdate;

          if (errors.length > 0) {
            throw new Error(errors[0]);
          }

          this.updateSelection(selectedOption);
          this.isSaving = false;
          this.$toast.show(this.successMessage(this.aiFeatureSetting));
        }
      } catch (error) {
        createAlert({
          message: this.errorMessage(error),
          error,
          captureError: true,
        });
        this.isSaving = false;
      }
    },
    updateSelection(selectedOption) {
      this.selectedOption = selectedOption.option;
      this.provider = selectedOption.provider;
      this.selfHostedModelId = selectedOption.selfHostedModelId;
    },
    errorMessage(error) {
      return error.message || this.$options.i18n.defaultErrorMessage;
    },
    successMessage(aiFeatureSetting) {
      return sprintf(this.$options.i18n.successMessage, {
        mainFeature: aiFeatureSetting.mainFeature,
        title: aiFeatureSetting.title,
      });
    },
  },
};
</script>
<template>
  <gl-collapsible-listbox
    class="md:gl-w-31"
    :selected="selectedOption"
    :items="dropdownItems"
    :toggle-text="dropdownToggleText"
    :header-text="s__('AdminAIPoweredFeatures|Compatible models')"
    :loading="isSaving"
    category="primary"
    block
    @select="onSelect"
  >
    <template #footer>
      <div class="gl-border-t-1 gl-border-t-dropdown !gl-p-2 gl-border-t-solid">
        <gl-button
          data-testid="add-self-hosted-model-button"
          :href="newSelfHostedModelPath"
          category="tertiary"
        >
          {{ s__('AdminAIPoweredFeatures|Add self-hosted model') }}
        </gl-button>
      </div>
    </template>
  </gl-collapsible-listbox>
</template>
