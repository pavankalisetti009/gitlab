<script>
import {
  GlFormGroup,
  GlButton,
  GlSprintf,
  GlLink,
  GlTable,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
} from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import DastVariablesModal from './dast_variables_modal.vue';

const mockVariables = [
  { variable: 'DAST_CHECKS_TO_EXCLUDE', value: '552.2,78.1' },
  { variable: 'DAST_CRAWL_GRAPH', value: 'true' },
];

export default {
  i18n: {
    label: s__('DastProfiles|Additional variables'),
    helpText: s__(
      'DastProfiles| Customize the behavior of DAST using additional variables. For a full list of available variables, refer to the %{linkStart}DAST documentation%{linkEnd}.',
    ),
    addVariableButtonLabel: s__('DastProfiles|Add variable'),
    optionalText: __('(optional)'),
  },
  dastDocumentationPath: helpPagePath(
    'user/application_security/dast/browser/configuration/variables',
  ),
  components: {
    GlFormGroup,
    GlButton,
    GlSprintf,
    GlLink,
    GlTable,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    DastVariablesModal,
  },
  props: {
    stacked: {
      type: Boolean,
      required: false,
      default: true,
    },
    value: {
      type: Array,
      required: false,
      default: () => mockVariables,
    },
  },
  data() {
    return {
      fields: [
        { key: 'variable', label: __('Variable') },
        { key: 'value', label: __('Value') },
        { key: 'actions', label: '' },
      ],
      existingVariables: this.value,
      additionalVariables: [],
    };
  },
  computed: {
    variableList() {
      return [...this.existingVariables, ...this.additionalVariables];
    },
  },
  watch: {
    variableList(newValue) {
      this.$emit('input', newValue);
    },
  },
  methods: {
    showAddVariableModal() {
      this.$refs.addVariableModal.show();
    },
    addVariableToList(newVariable) {
      this.additionalVariables.push(newVariable);
    },
    deleteVariableFromList(item) {
      const { variable: variableToBeDeleted } = item;
      this.existingVariables = this.existingVariables.filter(
        ({ variable }) => variable !== variableToBeDeleted,
      );
      this.additionalVariables = this.additionalVariables.filter(
        ({ variable }) => variable !== variableToBeDeleted,
      );
    },
    updateVariable(item) {
      return item;
    },

    editItem(item) {
      return {
        text: __('Edit'),
        action: () => this.updateVariable(item),
      };
    },
    deleteItem(item) {
      return {
        text: __('Delete'),
        action: () => this.deleteVariableFromList(item),
        extraAttrs: {
          class: '!gl-text-danger',
        },
      };
    },
  },
};
</script>

<template>
  <div class="row">
    <gl-form-group
      class="gl-mb-0"
      :class="{ 'col-md-6': !stacked, 'col-md-12': stacked }"
      :optional="true"
      :optional-text="$options.i18n.optionalText"
      :label="$options.i18n.label"
    >
      <template #label-description>
        <gl-sprintf :message="$options.i18n.helpText">
          <template #link="{ content }">
            <gl-link :href="$options.dastDocumentationPath" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </template>
      <gl-table
        :items="variableList"
        :fields="fields"
        bordered
        hover
        class="dast-variables-table"
        borderless
      >
        <template #cell(actions)="{ item }">
          <gl-disclosure-dropdown
            category="tertiary"
            variant="default"
            size="small"
            icon="ellipsis_v"
            no-caret
          >
            <gl-disclosure-dropdown-item :item="editItem(item)" />
            <gl-disclosure-dropdown-item :item="deleteItem(item)" />
          </gl-disclosure-dropdown> </template
      ></gl-table>
      <gl-button
        data-testid="additional-variables-btn"
        variant="confirm"
        category="secondary"
        @click="showAddVariableModal"
      >
        {{ $options.i18n.addVariableButtonLabel }}
      </gl-button>
    </gl-form-group>
    <dast-variables-modal ref="addVariableModal" @addVariable="addVariableToList" />
  </div>
</template>
