<script>
import { s__, sprintf } from '~/locale';
import { createAlert } from '~/alert';
import ModelSelectDropdown from 'ee/ai/shared/feature_settings/model_select_dropdown.vue';
import { getTypeFromGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_AI_SELF_HOSTED_MODEL } from 'ee_else_ce/graphql_shared/constants';
import { RELEASE_STATES } from '../../constants';
import updateAiFeatureSetting from '../graphql/mutations/update_ai_feature_setting.mutation.graphql';
import getAiFeatureSettingsQuery from '../graphql/queries/get_ai_feature_settings.query.graphql';
import getSelfHostedModelsQuery from '../../self_hosted_models/graphql/queries/get_self_hosted_models.query.graphql';
import { PROVIDERS, DUO_AGENT_PLATFORM_FEATURE, GITLAB_DEFAULT_MODEL } from '../constants';

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
    isGitlabManagedModelSelected() {
      const { provider, gitlabModel } = this.aiFeatureSetting;
      // Refers to the GitLab managed models offered by instance-level model selection
      return provider === PROVIDERS.VENDORED && gitlabModel?.ref;
    },
    isDefaultGitlabModelSelected() {
      const { provider, gitlabModel, defaultGitlabModel } = this.aiFeatureSetting;

      if (!defaultGitlabModel) return false;

      return Boolean(
        (provider === PROVIDERS.VENDORED && !gitlabModel) || provider === PROVIDERS.UNASSIGNED,
      );
    },
    selectedOption() {
      const { provider, selfHostedModel, gitlabModel } = this.aiFeatureSetting;
      let selected = provider;

      if (provider === PROVIDERS.SELF_HOSTED) {
        selected = selfHostedModel?.id;
      }

      if (this.isGitlabManagedModelSelected) {
        selected = gitlabModel?.ref;
      }

      if (this.isDefaultGitlabModelSelected) {
        selected = GITLAB_DEFAULT_MODEL;
      }

      return this.listItems
        .flatMap((item) => item.options ?? item)
        .find((item) => item.value === selected);
    },
    showVendoredModel() {
      const { feature = '' } = this.aiFeatureSetting;
      const isDuoAgentPlatform = feature === DUO_AGENT_PLATFORM_FEATURE;

      if (isDuoAgentPlatform) return false;

      return this.showVendoredModelOption;
    },
    listItems() {
      const { selfHostedModels, gitlabManagedModels } = this;

      const disabledOption = {
        value: PROVIDERS.DISABLED,
        text: s__('AdminAIPoweredFeatures|Disabled'),
      };
      const vendoredOption = {
        value: PROVIDERS.VENDORED,
        text: s__('AdminAIPoweredFeatures|GitLab AI vendor model'),
      };
      const items = [];

      if (selfHostedModels.length) {
        const otherOptions = this.showVendoredModel
          ? [vendoredOption, disabledOption]
          : [disabledOption];

        items.push({
          text: s__('AdminSelfHostedModels|Self-hosted models'),
          options: [...selfHostedModels, ...otherOptions],
        });
      }

      if (gitlabManagedModels.length) {
        items.push({
          text: s__('AdminSelfHostedModels|GitLab managed models'),
          options: gitlabManagedModels,
        });
      }

      return items;
    },
    selfHostedModels() {
      const validModels = this.aiFeatureSetting.validModels?.nodes || [];
      const gaModels = validModels.filter(({ releaseState }) => releaseState === RELEASE_STATES.GA);
      const betaModels = validModels.filter(
        ({ releaseState }) => releaseState === RELEASE_STATES.BETA,
      );

      // sorted by releaseState
      return [...gaModels, ...betaModels].map(({ name, modelDisplayName, id, releaseState }) => ({
        value: id,
        text: `${name} (${modelDisplayName})`,
        releaseState,
      }));
    },
    gitlabManagedModels() {
      const validGitlabModels = this.aiFeatureSetting.validGitlabModels?.nodes || [];
      const { defaultGitlabModel } = this.aiFeatureSetting;

      const models = validGitlabModels.map(({ name, ref }) => ({
        value: ref,
        text: name,
      }));

      if (defaultGitlabModel) {
        const text = sprintf(s__('AdminAIPoweredFeatures|GitLab default model (%{defaultModel})'), {
          defaultModel: defaultGitlabModel.name,
        });

        models.push({
          text,
          value: GITLAB_DEFAULT_MODEL,
        });
      }

      return models;
    },
  },

  methods: {
    async onSelect(selectedOption) {
      this.isSaving = true;

      const provider = this.getProvider(selectedOption);

      // We need to keep old implementation of AI vendor model option
      // until the instance-level model selection feature flag is fully rolled out.
      const isLegacyVendorOption = selectedOption === PROVIDERS.VENDORED;

      const offeredModelRef =
        provider === PROVIDERS.VENDORED && !isLegacyVendorOption ? selectedOption : null;
      const selfHostedModelId = provider === PROVIDERS.SELF_HOSTED ? selectedOption : null;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: updateAiFeatureSetting,
          variables: {
            input: {
              features: [this.aiFeatureSetting.feature.toUpperCase()],
              provider: provider.toUpperCase(),
              aiSelfHostedModelId: selfHostedModelId,
              offeredModelRef,
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
      if (option === PROVIDERS.DISABLED) return PROVIDERS.DISABLED;

      const gqlType = getTypeFromGraphQLId(option);

      if (gqlType === TYPENAME_AI_SELF_HOSTED_MODEL) return PROVIDERS.SELF_HOSTED;

      return PROVIDERS.VENDORED;
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
