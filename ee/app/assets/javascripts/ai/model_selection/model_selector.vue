<script>
import { s__, sprintf } from '~/locale';
import { createAlert } from '~/alert';
import { formatDefaultModelText } from 'ee/ai/shared/model_selection/utils';
import GitlabDefaultModelModal from 'ee/ai/model_selection/gitlab_default_model_modal.vue';
import ModelSelectDropdown from '../shared/feature_settings/model_select_dropdown.vue';
import updateAiNamespaceFeatureSettingsMutation from './graphql/update_ai_namespace_feature_settings.mutation.graphql';
import getAiNamespaceFeatureSettingsQuery from './graphql/get_ai_namepace_feature_settings.query.graphql';
import { GITLAB_DEFAULT_MODEL, SUPPRESS_DEFAULT_MODEL_MODAL_KEY } from './constants';

export default {
  name: 'ModelSelector',
  components: {
    GitlabDefaultModelModal,
    ModelSelectDropdown,
  },
  inject: ['groupId'],
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
  data() {
    return {
      isSaving: false,
    };
  },
  computed: {
    selectedModel() {
      return this.aiFeatureSetting.selectedModel?.ref || GITLAB_DEFAULT_MODEL;
    },
    defaultModelOption() {
      const { defaultModel } = this.aiFeatureSetting;
      const text = formatDefaultModelText(defaultModel);

      return {
        text,
        value: GITLAB_DEFAULT_MODEL,
        provider: defaultModel?.modelProvider || '',
        description: defaultModel?.modelDescription || '',
      };
    },
    listItems() {
      const modelOptions = this.aiFeatureSetting.selectableModels
        .map(({ ref, name, modelProvider, modelDescription }) => ({
          value: ref,
          text: name,
          provider: modelProvider,
          description: modelDescription,
        }))
        .sort((a, b) => a.text.localeCompare(b.text));

      return [...modelOptions, this.defaultModelOption];
    },
    selectedOption() {
      return this.listItems.find(({ value }) => value === this.selectedModel);
    },
  },
  methods: {
    checkShowModal() {
      return localStorage.getItem(SUPPRESS_DEFAULT_MODEL_MODAL_KEY) !== 'true';
    },
    onSelect(option) {
      const showModal = this.checkShowModal();

      if (option === GITLAB_DEFAULT_MODEL && showModal) {
        this.$refs.defaultModelModal.showModal();
        return;
      }

      this.onUpdate(option);
    },
    async onUpdate(option) {
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
          refetchQueries: [
            { query: getAiNamespaceFeatureSettingsQuery, variables: { groupId: this.groupId } },
          ],
        });

        if (data) {
          const { errors } = data.aiModelSelectionNamespaceUpdate;

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
  <div>
    <gitlab-default-model-modal ref="defaultModelModal" @confirm-submit="onUpdate" />
    <model-select-dropdown
      class="gl-w-34 lg:gl-w-48"
      :selected-option="selectedOption"
      :items="listItems"
      :is-loading="isSaving || batchUpdateIsSaving"
      @select="onSelect"
    />
  </div>
</template>
