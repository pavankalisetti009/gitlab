<script>
import { GlCollapsibleListbox, GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';

const PROVIDERS = {
  DISABLED: 0,
  VENDORED: 1,
  SELF_HOSTED: 2,
};

const FEATURE_DISABLED = 'DISABLED';

export default {
  name: 'ModelSelectDropdown',
  components: {
    GlCollapsibleListbox,
    GlButton,
  },
  props: {
    models: {
      type: Array,
      required: true,
    },
    newSelfHostedModelPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      featureProvider: null,
      selectedOption: null,
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
      return this.models.find((m) => m.id === this.selectedOption);
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
    onSelect(option) {
      if (option === FEATURE_DISABLED) {
        this.featureProvider = PROVIDERS.DISABLED;
      } else {
        this.featureProvider = PROVIDERS.SELF_HOSTED;
      }
      this.selectedOption = option;
    },
  },
};
</script>
<template>
  <gl-collapsible-listbox
    v-model="selectedOption"
    :items="dropdownItems"
    :toggle-text="dropdownToggleText"
    :header-text="s__('AdminAIPoweredFeatures|Self-hosted models')"
    category="primary"
    fluid-width
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
