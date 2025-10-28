<script>
import { uniqueId } from 'lodash';
import {
  GlForm,
  GlFormCheckbox,
  GlFormCheckboxGroup,
  GlFormGroup,
  GlFormInput,
  GlModal,
} from '@gitlab/ui';
import { __, s__ } from '~/locale';

export default {
  name: 'AiCatalogAddFlowToProjectModal',
  components: {
    GlForm,
    GlFormCheckbox,
    GlFormCheckboxGroup,
    GlFormGroup,
    GlFormInput,
    GlModal,
  },
  inject: {
    flowTriggersEventTypeOptions: {
      default: [],
    },
  },
  data() {
    return {
      triggerTypes: this.flowTriggersEventTypeOptions.map((option) => option.value),
    };
  },
  computed: {
    formId() {
      return uniqueId('add-flow-to-project-form-');
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
  },
  methods: {
    findTriggerTypeValue(text) {
      const triggerType = this.flowTriggersEventTypeOptions.find((option) => option.text === text);
      return triggerType?.value !== undefined ? String(triggerType.value) : '';
    },
    handleSubmit(input) {
      this.$emit('submit', input);
    },
  },

  modal: {
    actionPrimary: {
      text: __('Enable'),
      attributes: {
        variant: 'confirm',
        type: 'submit',
      },
    },
    actionSecondary: {
      text: __('Cancel'),
    },
  },
};
</script>

<template>
  <gl-modal
    modal-id="add-flow-to-project-modal"
    :title="s__('AICatalog|Enable flow in project')"
    :action-primary="$options.modal.actionPrimary"
    :action-secondary="$options.modal.actionSecondary"
  >
    <gl-form :id="formId" @submit.prevent="handleSubmit">
      <gl-form-group
        :label="s__('AICatalog|Flow')"
        :label-description="s__('AICatalog|Only flows enabled in your group will be shown here.')"
      >
        <gl-form-input />
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
