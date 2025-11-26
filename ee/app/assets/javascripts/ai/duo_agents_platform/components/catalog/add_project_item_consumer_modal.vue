<script>
import { uniqueId } from 'lodash';
import { GlForm, GlFormCheckbox, GlFormCheckboxGroup, GlFormGroup, GlModal } from '@gitlab/ui';
import { __ } from '~/locale';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { FLOW_TRIGGER_TYPES } from 'ee/ai/duo_agents_platform/constants';
import GroupItemConsumerDropdown from './group_item_consumer_dropdown.vue';

export default {
  name: 'AddProjectItemConsumerModal',
  components: {
    GlForm,
    GlFormCheckbox,
    GlFormCheckboxGroup,
    GlFormGroup,
    GlModal,
    ErrorsAlert,
    GroupItemConsumerDropdown,
  },
  props: {
    itemTypes: {
      type: Array,
      required: true,
    },
    modalId: {
      type: String,
      required: true,
    },
    modalTexts: {
      type: Object,
      required: true,
    },
    showTriggers: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      errors: [],
      isDirty: false,
      selectedGroupItemConsumer: {},
      triggerTypes: this.showTriggers ? FLOW_TRIGGER_TYPES.map((type) => type.value) : [],
    };
  },
  computed: {
    formId() {
      return uniqueId('add-project-item-consumer-form-');
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
        actionCancel: {
          text: __('Cancel'),
        },
      };
    },
    isGroupItemConsumerValid() {
      return !this.isDirty || this.selectedGroupItemConsumer.id !== undefined;
    },
    isTriggersValid() {
      return !this.showTriggers || !this.isDirty || this.triggerTypes.length > 0;
    },
  },
  methods: {
    resetForm() {
      this.selectedGroupItemConsumer = {};
      this.triggerTypes = this.showTriggers ? FLOW_TRIGGER_TYPES.map((type) => type.value) : [];
    },
    handleSubmit() {
      this.isDirty = true;
      if (!this.isGroupItemConsumerValid || !this.isTriggersValid) {
        return;
      }
      this.$emit('submit', {
        itemId: this.selectedGroupItemConsumer.item?.id,
        itemName: this.selectedGroupItemConsumer.item?.name,
        parentItemConsumerId: this.selectedGroupItemConsumer.id,
        ...(this.showTriggers ? { triggerTypes: this.triggerTypes } : {}),
      });
      this.$refs.modal.hide();
      this.resetForm();
    },
    onHidden() {
      this.errors = [];
      this.isDirty = false;
    },
    onGroupItemConsumerSelect(itemConsumer) {
      this.selectedGroupItemConsumer = itemConsumer;
    },
    onError() {
      this.errors = [this.modalTexts.error];
    },
  },
  FLOW_TRIGGER_TYPES,
};
</script>

<template>
  <gl-modal
    ref="modal"
    :modal-id="modalId"
    :title="modalTexts.title"
    :action-primary="modal.actionPrimary"
    :action-cancel="modal.actionCancel"
    @primary.prevent
    @hidden="onHidden"
  >
    <errors-alert class="gl-mt-5" :errors="errors" @dismiss="errors = []" />
    <gl-form :id="formId" @submit.prevent="handleSubmit">
      <gl-form-group
        :label="modalTexts.label"
        :label-description="modalTexts.labelDescription"
        label-for="group-item-consumer-dropdown"
        :state="isGroupItemConsumerValid"
        :invalid-feedback="modalTexts.invalidFeedback"
      >
        <group-item-consumer-dropdown
          id="group-item-consumer-dropdown"
          :value="selectedGroupItemConsumer.id"
          :dropdown-texts="modalTexts.dropdownTexts"
          :is-valid="isGroupItemConsumerValid"
          :item-types="itemTypes"
          @input="onGroupItemConsumerSelect"
          @error="onError"
        />
      </gl-form-group>
      <gl-form-group
        v-if="showTriggers"
        :label="s__('AICatalog|Add triggers')"
        :label-description="
          s__(
            'AICatalog|Choose what events in this project trigger the flow. You can change this later.',
          )
        "
        label-for="flow-triggers"
        :state="isTriggersValid"
        :invalid-feedback="s__('AICatalog|Select at least one trigger.')"
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
