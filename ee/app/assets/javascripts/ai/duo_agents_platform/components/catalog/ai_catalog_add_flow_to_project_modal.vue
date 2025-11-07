<script>
import { uniqueId } from 'lodash';
import { GlForm, GlFormCheckbox, GlFormCheckboxGroup, GlFormGroup, GlModal } from '@gitlab/ui';
import { __ } from '~/locale';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { FLOW_TRIGGER_TYPES } from 'ee/ai/duo_agents_platform/constants';
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
  props: {
    modalId: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      errors: [],
      isDirty: false,
      selectedFlowConsumer: {},
      triggerTypes: FLOW_TRIGGER_TYPES.map((type) => type.value),
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
    isFlowValid() {
      return !this.isDirty || this.selectedFlowConsumer.id !== undefined;
    },
  },
  methods: {
    handleSubmit() {
      this.isDirty = true;
      if (!this.isFlowValid) {
        return;
      }
      this.$refs.modal.hide();
      this.$emit('submit', {
        itemId: this.selectedFlowConsumer.item?.id,
        flowName: this.selectedFlowConsumer.item?.name,
        parentItemConsumerId: this.selectedFlowConsumer.id,
        triggerTypes: this.triggerTypes,
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
  FLOW_TRIGGER_TYPES,
};
</script>

<template>
  <gl-modal
    ref="modal"
    :modal-id="modalId"
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
            v-for="triggerType in $options.FLOW_TRIGGER_TYPES"
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
