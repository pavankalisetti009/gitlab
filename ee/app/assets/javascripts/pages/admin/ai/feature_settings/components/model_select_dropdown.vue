<script>
import { GlCollapsibleListbox, GlButton } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { createAlert } from '~/alert';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import updateAiFeatureSetting from '../graphql/mutations/update_ai_feature_setting.graphql';

const PROVIDERS = {
  DISABLED: 'DISABLED',
  VENDORED: 'VENDORED',
  SELF_HOSTED: 'SELF_HOSTED',
};

const FEATURE_DISABLED = 'DISABLED';

export default {
  name: 'ModelSelectDropdown',
  components: {
    GlCollapsibleListbox,
    GlButton,
  },
  props: {
    featureSetting: {
      type: Object,
      required: true,
    },
    models: {
      type: Array,
      required: true,
    },
    newSelfHostedModelPath: {
      type: String,
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
    return {
      feature: this.featureSetting.feature,
      provider: this.featureSetting.provider,
      selfHostedModelId: this.featureSetting.selfHostedModelId,
      selectedOption: null,
      isSaving: false,
    };
  },
  computed: {
    dropdownItems() {
      const modelOptions = this.models.map((model) => ({
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
      return this.models.find((m) => m.id === this.selfHostedModelId);
    },
    dropdownToggleText() {
      if (!this.selectedOption) {
        return s__('AdminAIPoweredFeatures|Select a self-hosted model');
      }
      if (this.selectedOption === FEATURE_DISABLED) {
        return s__('AdminAIPoweredFeatures|Disabled');
      }

      return `${this.selectedModel.name} (${this.selectedModel.model})`;
    },
  },
  methods: {
    async onSelect(option) {
      this.isSaving = true;

      try {
        const provider = option === FEATURE_DISABLED ? PROVIDERS.DISABLED : PROVIDERS.SELF_HOSTED;

        const { data } = await this.$apollo.mutate({
          mutation: updateAiFeatureSetting,
          variables: {
            input: {
              feature: this.feature.toUpperCase(),
              provider,
              selfHostedModelId:
                option === FEATURE_DISABLED
                  ? null
                  : convertToGraphQLId('Ai::SelfHostedModel', option),
            },
          },
        });

        if (data) {
          const { errors } = data.aiFeatureSettingUpdate;

          if (errors.length > 0) {
            throw new Error(errors[0]);
          }

          this.selectedOption = option;
          this.provider = provider;
          this.selfHostedModelId = option === FEATURE_DISABLED ? null : option;
          this.isSaving = false;
          this.$toast.show(this.successMessage(this.featureSetting));
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
    errorMessage(error) {
      return error.message || this.$options.i18n.defaultErrorMessage;
    },
    successMessage(featureSetting) {
      return sprintf(this.$options.i18n.successMessage, {
        mainFeature: featureSetting.mainFeature,
        title: featureSetting.title,
      });
    },
  },
};
</script>
<template>
  <gl-collapsible-listbox
    class="gl-w-31"
    :selected="selectedOption"
    :items="dropdownItems"
    :toggle-text="dropdownToggleText"
    :header-text="s__('AdminAIPoweredFeatures|Self-hosted models')"
    :loading="isSaving"
    category="primary"
    block
    @select="onSelect"
  >
    <template #footer>
      <div class="gl-border-t-1 gl-border-t-gray-200 !gl-p-2 gl-border-t-solid">
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
