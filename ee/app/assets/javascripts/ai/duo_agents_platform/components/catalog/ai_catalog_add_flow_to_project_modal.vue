<script>
import { uniqueId } from 'lodash';
import { GlForm, GlFormCheckbox, GlFormCheckboxGroup, GlFormGroup, GlModal } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import AiCatalogGroupFlowDropdown from './ai_catalog_group_flow_dropdown.vue';

export default {
  name: 'AiCatalogAddFlowToProjectModal',
  components: {
    GlForm,
    GlFormCheckbox,
    GlFormCheckboxGroup,
    GlFormGroup,
    GlModal,
    ErrorsAlert,
    AiCatalogGroupFlowDropdown,
  },
  inject: {
    flowTriggersEventTypeOptions: {
      default: [],
    },
  },
  data() {
    return {
      errors: [],
      isDirty: false,
      selectedFlowConsumer: {},
      triggerTypes: this.flowTriggersEventTypeOptions.map((option) => option.value),
    };
  },
  computed: {
    formId() {
      return uniqueId('add-flow-to-project-form-');
    },
    modal() {
      return {
        actionPrimary: {
          text: __('Enable'),
          attributes: {
            variant: 'confirm',
            type: 'submit',
            form: this.formId,
          },
        },
        actionSecondary: {
          text: __('Cancel'),
        },
      };
    },
    triggerTypeOptions() {
      return [
        {
          text: __('Mention'),
          help: s__(
            'AICatalog|Trigger this flow when the service account user is mentioned in an issue or merge request.',
          ),
          value: this.findTriggerTypeValue('Mention'), // eslint-disable-line @gitlab/require-i18n-strings
        },
        {
          text: __('Assign'),
          help: s__(
            'AICatalog|Trigger this flow when the service account user is assigned to issue or merge request.',
          ),
          value: this.findTriggerTypeValue('Assign'), // eslint-disable-line @gitlab/require-i18n-strings
        },
        {
          text: __('Assign reviewer'),
          help: s__(
            'AICatalog|Trigger this flow when the service account user is assigned as a reviewer to a merge request.',
          ),
          value: this.findTriggerTypeValue('Assign reviewer'), // eslint-disable-line @gitlab/require-i18n-strings
        },
      ];
    },
    isFlowValid() {
      return !this.isDirty || this.selectedFlowConsumer.id !== undefined;
    },
  },
  methods: {
    findTriggerTypeValue(text) {
      const triggerType = this.flowTriggersEventTypeOptions.find((option) => option.text === text);
      return triggerType?.value !== undefined ? String(triggerType.value) : '';
    },
    handleSubmit(input) {
      this.isDirty = true;
      if (!this.isFlowValid) {
        return;
      }
      this.$emit('submit', {
        itemId: this.selectedFlowConsumer.item?.id,
        parentItemConsumerId: this.selectedFlowConsumer.id,
        triggerTypes: this.triggerTypes,
        ...input,
      });
    },
    onHidden() {
      this.isDirty = false;
    },
    onFlowSelect(flowId) {
      this.selectedFlowConsumer = flowId;
    },
    onFlowError(error) {
      this.errors = [error];
    },
  },
};
</script>

<template>
  <gl-modal
    modal-id="add-flow-to-project-modal"
    :title="s__('AICatalog|Enable flow in project')"
    :action-primary="modal.actionPrimary"
    :action-secondary="modal.actionSecondary"
    @primary.prevent
    @hidden="onHidden"
  >
    <errors-alert class="gl-mt-5" :errors="errors" @dismiss="errors = []" />
    <gl-form :id="formId" @submit.prevent="handleSubmit">
      <gl-form-group
        :label="s__('AICatalog|Flow')"
        :label-description="s__('AICatalog|Only flows enabled in your group will be shown here.')"
        label-for="flow-dropdown"
        :state="isFlowValid"
        :invalid-feedback="s__('AICatalog|Flow is required.')"
      >
        <ai-catalog-group-flow-dropdown
          id="flow-dropdown"
          :value="selectedFlowConsumer.id"
          :is-valid="isFlowValid"
          @input="onFlowSelect"
          @error="onFlowError"
        />
      </gl-form-group>
      <gl-form-group
        :label="s__('AICatalog|Add flow triggers')"
        :label-description="
          s__(
            'AICatalog|Choose what events in this project trigger the flow. You can change this later.',
          )
        "
        label-for="flow-triggers"
        optional
        :optional-text="__('(optional)')"
      >
        <gl-form-checkbox-group id="flow-triggers" v-model="triggerTypes">
          <gl-form-checkbox
            v-for="triggerType in triggerTypeOptions"
            :key="triggerType.value"
            :value="triggerType.value"
          >
            {{ triggerType.text }}
            <template #help>{{ triggerType.help }}</template>
          </gl-form-checkbox>
        </gl-form-checkbox-group>
      </gl-form-group>
    </gl-form>
  </gl-modal>
</template>
