<script>
import { s__, sprintf } from '~/locale';
import { createAlert } from '~/alert';
import ModelSelectDropdown from 'ee/ai/shared/feature_settings/model_select_dropdown.vue';
import { RELEASE_STATES } from '../../constants';
import updateAiFeatureSetting from '../graphql/mutations/update_ai_feature_setting.mutation.graphql';
import getAiFeatureSettingsQuery from '../graphql/queries/get_ai_feature_settings.query.graphql';
import getSelfHostedModelsQuery from '../../self_hosted_models/graphql/queries/get_self_hosted_models.query.graphql';
import { PROVIDERS } from '../constants';

export default {
  name: 'ModelSelector',
  components: {
    ModelSelectDropdown,
  },
  inject: ['showVendoredModelOption'],
  props: {
    aiFeatureSetting: {
      type: Object,
      required: true,
    },
    batchUpdateIsSaving: {
      type: Boolean,
      required: true,
    },
  },
  i18n: {
    defaultErrorMessage: s__(
      'AdminSelfHostedModels|An error occurred while updating the self-hosted model, please try again.',
    ),
    successMessage: s__('AdminSelfHostedModels|Successfully updated %{mainFeature} / %{title}'),
  },
  data() {
    return {
      isSaving: false,
    };
  },
  computed: {
    selectedOption() {
      const { provider, selfHostedModel } = this.aiFeatureSetting;

      const selected = provider === PROVIDERS.SELF_HOSTED ? selfHostedModel?.id : provider;

      return this.listItems.find((item) => item.value === selected);
    },
    listItems() {
      const validModels = this.aiFeatureSetting.validModels?.nodes || [];
      const gaModels = validModels.filter(({ releaseState }) => releaseState === RELEASE_STATES.GA);
      const betaModels = validModels.filter(
        ({ releaseState }) => releaseState === RELEASE_STATES.BETA,
      );

      // sort compatible models by releaseState
      const modelOptions = [...gaModels, ...betaModels].map(
        ({ name, modelDisplayName, id, releaseState }) => ({
          value: id,
          text: `${name} (${modelDisplayName})`,
          releaseState,
        }),
      );

      const disabledOption = {
        value: PROVIDERS.DISABLED,
        text: s__('AdminAIPoweredFeatures|Disabled'),
      };

      const vendoredOption = {
        value: PROVIDERS.VENDORED,
        text: s__('AdminAIPoweredFeatures|GitLab AI vendor model'),
      };

      const otherOptions = this.showVendoredModelOption
        ? [vendoredOption, disabledOption]
        : [disabledOption];

      return [...modelOptions, ...otherOptions];
    },
  },
  methods: {
    async onSelect(selectedOption) {
      this.isSaving = true;

      try {
        const provider = this.getProvider(selectedOption);
        const aiSelfHostedModelId = provider === PROVIDERS.SELF_HOSTED ? selectedOption : null;

        const { data } = await this.$apollo.mutate({
          mutation: updateAiFeatureSetting,
          variables: {
            input: {
              features: [this.aiFeatureSetting.feature.toUpperCase()],
              provider: provider.toUpperCase(),
              aiSelfHostedModelId,
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

          this.$toast.show(this.successMessage(this.aiFeatureSetting));
        }
      } catch (error) {
        createAlert({
          message: this.errorMessage(error),
          error,
          captureError: true,
        });
      } finally {
        this.isSaving = false;
      }
    },
    getProvider(option) {
      const isDisabled = option === PROVIDERS.DISABLED;
      const isVendored = option === PROVIDERS.VENDORED;

      if (isDisabled || isVendored) return option;

      return PROVIDERS.SELF_HOSTED;
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
  <model-select-dropdown
    :selected-option="selectedOption"
    :items="listItems"
    :placeholder-dropdown-text="s__('AdminAIPoweredFeatures|Select a self-hosted model')"
    :is-loading="isSaving || batchUpdateIsSaving"
    is-feature-setting-dropdown
    @select="onSelect"
  />
</template>
