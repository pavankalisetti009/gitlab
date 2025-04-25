<script>
import { GlButton, GlModal } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import VariablesSelector from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/variables_selector.vue';

export default {
  ACTION_CANCEL: { text: __('Cancel') },
  i18n: {
    newVariableButtonText: s__('SecurityOrchestration|Add another variable'),
    allowListTitle: s__('SecurityOrchestration|Edit allowlist'),
    denyListTitle: s__('SecurityOrchestration|Edit denylist'),
    denyListButton: s__('SecurityOrchestration|Save denylist'),
    allowListButton: s__('SecurityOrchestration|Save allowlist'),
    tableHeaderAllowList: s__('SecurityOrchestration|Variables that can be overridden:'),
    tableHeaderDenyList: s__('SecurityOrchestration|Variables that cannot be overriden:'),
    tableSubheader: s__('SecurityOrchestration|Key'),
  },
  name: 'VariablesOverrideModal',
  components: {
    GlButton,
    GlModal,
    VariablesSelector,
  },
  props: {
    exceptions: {
      type: Array,
      required: false,
      default: () => [],
    },
    isVariablesOverrideAllowed: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      items: this.exceptions,
    };
  },
  computed: {
    tableHeader() {
      return this.isVariablesOverrideAllowed
        ? this.$options.i18n.tableHeaderDenyList
        : this.$options.i18n.tableHeaderAllowList;
    },
    modalTitle() {
      return this.isVariablesOverrideAllowed
        ? this.$options.i18n.denyListTitle
        : this.$options.i18n.allowListTitle;
    },
    primaryAction() {
      return {
        text: this.isVariablesOverrideAllowed
          ? this.$options.i18n.denyListButton
          : this.$options.i18n.allowListButton,
        attributes: {
          variant: 'confirm',
        },
      };
    },
    hasEmptyPlaceholder() {
      return this.selectedExceptions.includes('');
    },
    selectedExceptions() {
      return this.items.length > 0 ? this.items : [''];
    },
  },
  watch: {
    exceptions(exceptions) {
      this.items = exceptions;
    },
  },
  methods: {
    addVariableSelector() {
      this.items.push('');
    },
    hideModalWindow() {
      this.$refs.modal.hide();
    },
    selectExceptions() {
      this.$emit('select-exceptions', this.items?.filter(Boolean));
    },
    getAlreadySelectedItems(variable) {
      return this.selectedExceptions.filter((item) => item !== variable);
    },
    selectException(variable, index) {
      this.items.splice(index, 1, variable);
    },
    removeException(index) {
      this.items.splice(index, 1);
    },
    /**
     * Used in parent component
     */
    // eslint-disable-next-line vue/no-unused-properties
    showModalWindow() {
      this.$refs.modal.show();
    },
  },
};
</script>

<template>
  <gl-modal
    ref="modal"
    :action-cancel="$options.ACTION_CANCEL"
    :action-primary="primaryAction"
    :title="modalTitle"
    scrollable
    size="md"
    content-class="security-policies-variables-modal-min-height"
    modal-id="deny-allow-list-modal"
    @canceled="hideModalWindow"
    @primary="selectExceptions"
  >
    <div class="gl-bg-default gl-px-4 gl-py-5">
      <p class="gl-font-bold" data-testid="table-header">
        {{ tableHeader }}
      </p>

      <p class="gl-mb-4 gl-border-b-1 gl-border-b-default gl-pb-2 gl-border-b-solid">
        {{ $options.i18n.tableSubheader }}
      </p>

      <variables-selector
        v-for="(variable, index) of selectedExceptions"
        :key="index"
        :already-selected-items="getAlreadySelectedItems(variable)"
        class="gl-mb-3"
        :selected="variable"
        @remove="removeException(index)"
        @select="selectException($event, index)"
      />

      <gl-button
        data-testid="add-button"
        category="secondary"
        :disabled="hasEmptyPlaceholder"
        variant="confirm"
        size="small"
        @click="addVariableSelector"
      >
        {{ $options.i18n.newVariableButtonText }}
      </gl-button>
    </div>
  </gl-modal>
</template>
