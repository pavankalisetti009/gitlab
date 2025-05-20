<script>
import { s__, sprintf } from '~/locale';
import ModelSelectDropdown from '../shared/feature_settings/model_select_dropdown.vue';

export default {
  name: 'ModelSelector',
  components: {
    ModelSelectDropdown,
  },
  props: {
    aiFeatureSetting: {
      type: Object,
      required: true,
    },
  },
  i18n: {
    successMessage: s__('AdminSelfHostedModels|Successfully updated %{mainFeature} / %{title}'),
  },
  data() {
    const { selectableModels, selectedModel } = this.aiFeatureSetting;

    return {
      selectableModels,
      selectedModel: selectedModel.ref,
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
        value: 'gitlab',
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

      // TODO: Invoke update mutation here when implementation is ready
      this.selectedModel = option;
      this.isSaving = false;

      this.$toast.show(this.successMessage(this.aiFeatureSetting));
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
    :dropdown-toggle-text="dropdownToggleText"
    :is-loading="isSaving"
    @select="onSelect"
  />
</template>
