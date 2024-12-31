<script>
import {
  GlModal,
  GlCollapsibleListbox,
  GlFormGroup,
  GlFormInput,
  GlFormTextarea,
  GlFormRadio,
  GlFormRadioGroup,
} from '@gitlab/ui';
import { s__, __ } from '~/locale';
import DAST_VARIABLES from '../dast_variables';
import { booleanOptions } from '../constants';

const getEmptyVariable = () => ({
  id: null,
  value: '',
  type: null,
  description: '',
  example: '',
});

export default {
  name: 'DastVariablesModal',
  components: {
    GlModal,
    GlCollapsibleListbox,
    GlFormGroup,
    GlFormInput,
    GlFormRadio,
    GlFormTextarea,
    GlFormRadioGroup,
  },
  props: {
    preSelectedVariables: {
      type: Array,
      required: false,
      default: () => [],
    },
    variable: {
      type: Object,
      required: false,
      default: () => getEmptyVariable(),
    },
  },
  i18n: {
    title: s__('DastProfiles|Add DAST variable'),
    dropdownPlaceholder: s__('DastProfiles|Select a variable'),
    searchPlaceholder: s__('DastProfiles|Search...'),
    emptySearchResult: s__('DastProfiles|No variables found'),
    variableLabel: s__('DastProfiles|Variable'),
    valueLabel: s__('DastProfiles|Value'),
    requiredFieldFeedback: s__('DastProfiles|Field must not be blank'),
  },
  data() {
    return {
      selectedVariable: {
        ...this.variable,
      },
      searchTerm: '',
      selectedValueValid: true,
      selectedVariableValid: true,
    };
  },
  computed: {
    dropdownText() {
      if (this.selectedVariable.id) {
        return this.selectedVariable.id;
      }
      return this.$options.i18n.dropdownPlaceholder;
    },
    modalActionPrimary() {
      return {
        text: s__('DastProfiles|Add variable'),
      };
    },
    modalActionCancel() {
      return {
        text: __('Cancel'),
        attributes: {
          variant: 'default',
        },
      };
    },
    items() {
      const preSelectedVariablesNames = this.preSelectedVariables
        .map((existVariable) => existVariable.variable)
        .filter(Boolean);

      const searchTermLower = this.searchTerm?.toLowerCase() || '';

      const filteredVariables = Object.entries(DAST_VARIABLES).filter(
        ([id]) =>
          (!searchTermLower || id.toLowerCase().includes(searchTermLower)) &&
          !preSelectedVariablesNames.includes(id),
      );

      return filteredVariables.map(([id, { description }]) => ({
        value: id,
        text: id,
        secondaryText: description,
      }));
    },
    componentByType() {
      if (this.selectedVariable.type) {
        if (this.checkSelectorType('selector')) {
          return GlFormTextarea;
        }

        return GlFormInput;
      }
      return null;
    },
  },
  methods: {
    show() {
      this.$refs.modal.show();
    },
    addVariable(modalEvent) {
      if (!this.selectedVariable.type) {
        this.selectedVariableValid = false;
        modalEvent.preventDefault();
        return;
      }
      if (!this.selectedVariable.id || !this.selectedVariable.value) {
        this.selectedValueValid = false;
        modalEvent.preventDefault();
        return;
      }
      const { id, value, type } = this.selectedVariable;
      this.$emit('addVariable', {
        variable: id,
        value,
        type,
      });
    },
    onSearch(searchTerm) {
      this.searchTerm = searchTerm.trim().toLowerCase();
    },
    resetModal() {
      this.selectedVariable = getEmptyVariable();
      this.searchTerm = '';
    },
    onSelect(id) {
      const { type, description, example } = DAST_VARIABLES[id] || {};
      this.selectedVariable.id = id;
      this.selectedVariable.value = '';
      this.selectedVariable.type = type || null;
      this.selectedVariable.description = description || '';
      this.selectedVariable.example = example || '';
      this.selectedValueValid = true;
      this.selectedVariableValid = true;
    },
    checkSelectorType(type) {
      return this.selectedVariable.type === type;
    },
  },
  booleanOptions,
};
</script>

<template>
  <gl-modal
    ref="modal"
    size="sm"
    modal-id="dast-variable-modal"
    :action-primary="modalActionPrimary"
    :action-cancel="modalActionCancel"
    :title="$options.i18n.title"
    @primary="addVariable"
    @hidden="resetModal"
  >
    <gl-form-group
      :label="$options.i18n.variableLabel"
      label-for="dast_variable_selector"
      :invalid-feedback="$options.i18n.requiredFieldFeedback"
      :state="selectedVariableValid"
    >
      <gl-collapsible-listbox
        id="dast_variable_selector"
        block
        searchable
        is-check-centered
        :items="items"
        :toggle-text="dropdownText"
        :search-placeholder="$options.i18n.searchPlaceholder"
        :no-results-text="$options.i18n.emptySearchResult"
        fluid-width
        @search="onSearch"
        @select="onSelect($event)"
      >
        <template #list-item="{ item: { text, secondaryText } }">
          <strong>{{ text }}</strong>
          <div class="gl-text-sm gl-text-subtle">{{ secondaryText }}</div>
        </template>
      </gl-collapsible-listbox>
    </gl-form-group>
    <gl-form-group
      v-if="selectedVariable.type"
      :label="$options.i18n.valueLabel"
      :label-description="selectedVariable.description"
      label-for="dast_value_input"
      :invalid-feedback="$options.i18n.requiredFieldFeedback"
      :state="selectedValueValid"
    >
      <gl-form-radio-group
        v-if="checkSelectorType('boolean')"
        id="dast_value_input"
        v-model="selectedVariable.value"
      >
        <gl-form-radio
          v-for="option in $options.booleanOptions"
          :key="option.value"
          :value="option.value"
        >
          {{ option.text }}
        </gl-form-radio>
      </gl-form-radio-group>

      <component
        :is="componentByType"
        v-else
        id="dast_value_input"
        v-model="selectedVariable.value"
        :placeholder="`Ex: ${selectedVariable.example}`"
        no-resize
      />
    </gl-form-group>
  </gl-modal>
</template>
