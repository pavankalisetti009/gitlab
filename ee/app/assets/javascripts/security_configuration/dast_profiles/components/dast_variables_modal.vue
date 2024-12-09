<script>
import { GlModal, GlCollapsibleListbox, GlFormGroup, GlFormInput } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import DAST_VARIABLES from '../dast_variables';

export default {
  name: 'DastVariablesModal',
  components: {
    GlModal,
    GlCollapsibleListbox,
    GlFormGroup,
    GlFormInput,
  },
  props: {
    preSelectedVariables: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    variable: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  i18n: {
    title: s__('DastProfiles|Add DAST variable'),
    dropdownPlaceholder: s__('DastProfiles|Select a variable'),
    searchPlaceholder: s__('DastProfiles|Search...'),
    emptySearchResult: s__('DastProfiles|No variables found'),
    variableLabel: s__('DastProfiles|Variable'),
    valueLabel: s__('DastProfiles|Value'),
  },
  data() {
    return {
      selectedVariableId: this.variable?.id || null,
      selectedVariableValue: this.variable?.value || '',
      searchTerm: '',
    };
  },
  computed: {
    dropdownText() {
      if (this.selectedVariableId) {
        return this.selectedVariableId;
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
      const filteredVariables = Object.entries(DAST_VARIABLES).filter(
        ([id]) => !this.searchTerm || id.toLowerCase().includes(this.searchTerm.toLowerCase()),
      );

      return filteredVariables.map(([id, { description }]) => ({
        value: id,
        text: id,
        secondaryText: description,
      }));
    },
  },
  methods: {
    show() {
      this.$refs.modal.show();
    },
    addVariable() {
      this.$emit('addVariable', {
        variable: this.selectedVariableId,
        value: this.selectedVariableValue,
      });
    },
    onSearch(searchTerm) {
      this.searchTerm = searchTerm.trim().toLowerCase();
    },
    resetModal() {
      this.selectedVariableId = null;
      this.selectedVariableValue = '';
      this.searchTerm = '';
    },
  },
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
    <gl-form-group :label="$options.i18n.variableLabel" label-for="dast_variable_selector">
      <gl-collapsible-listbox
        id="dast_variable_selector"
        v-model="selectedVariableId"
        block
        searchable
        is-check-centered
        :items="items"
        :toggle-text="dropdownText"
        :search-placeholder="$options.i18n.searchPlaceholder"
        :no-results-text="$options.i18n.emptySearchResult"
        fluid-width
        @search="onSearch"
      >
        <!-- <template #list-item="{ item: { text, secondaryText, icon } }"> </template> -->
      </gl-collapsible-listbox>
    </gl-form-group>
    <gl-form-group :label="$options.i18n.valueLabel" label-for="dast_value_input">
      <gl-form-input id="dast_value_input" v-model="selectedVariableValue" />
    </gl-form-group>
  </gl-modal>
</template>
