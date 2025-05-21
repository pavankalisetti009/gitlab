<script>
import { s__, sprintf } from '~/locale';
import { createAlert } from '~/alert';
import ModelSelectDropdown from '../shared/feature_settings/model_select_dropdown.vue';
import updateAiNamespaceFeatureSettingsMutation from './graphql/update_ai_namespace_feature_settings.mutation.graphql';

export default {
  name: 'ModelSelector',
  components: {
    ModelSelectDropdown,
  },
  inject: ['groupId'],
  props: {
    aiFeatureSetting: {
      type: Object,
      required: true,
    },
  },
  data() {
    const { selectableModels, selectedModel } = this.aiFeatureSetting;

    return {
      selectableModels,
      selectedModel: selectedModel?.ref || '',
      isSaving: false,
    };
  },
  computed: {
    listItems() {
      const modelOptions = this.selectableModels.map(({ ref, name }) => ({
        value: ref,
        text: name,
      }));

      const defaultModelOption = {
        value: '', // the GitLab Default model is represented by an empty string
        text: s__('AdminAIPoweredFeatures|GitLab Default'),
      };

      return [...modelOptions, defaultModelOption];
    },
    selectedOption() {
      return this.listItems.find(({ value }) => value === this.selectedModel);
    },
    dropdownToggleText() {
      return this.selectedOption?.text;
    },
  },
  methods: {
    async onSelect(option) {
      this.isSaving = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: updateAiNamespaceFeatureSettingsMutation,
          variables: {
            input: {
              features: [this.aiFeatureSetting.feature.toUpperCase()],
              groupId: this.groupId,
              offeredModelRef: option,
            },
          },
        });

        if (data) {
          const { errors } = data.aiModelSelectionNamespaceUpdate;

          if (errors.length > 0) {
            throw new Error(errors[0]);
          }

          this.selectedModel = option;
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
    successMessage(aiFeatureSetting) {
      return sprintf(s__('ModelSelection|Successfully updated %{mainFeature} / %{title}'), {
        mainFeature: aiFeatureSetting.mainFeature,
        title: aiFeatureSetting.title,
      });
    },
    errorMessage(error) {
      return (
        error.message ||
        s__(
          'ModelSelection|An error occurred while updating the feature setting. Please try again.',
        )
      );
    },
  },
};
</script>
<template>
  <model-select-dropdown
    :selected-option="selectedOption"
    :items="listItems"
    :dropdown-toggle-text="dropdownToggleText"
    :is-loading="isSaving"
    @select="onSelect"
  />
</template>
