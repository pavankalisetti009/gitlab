<script>
import { uniqueId } from 'lodash';
import { GlButton, GlForm, GlFormFields, GlFormTextarea } from '@gitlab/ui';
import { formValidators } from '@gitlab/ui/dist/utils';
import {
  MAX_LENGTH_NAME,
  MAX_LENGTH_DESCRIPTION,
  MAX_LENGTH_PROMPT,
} from 'ee/ai/catalog/constants/constants';
import { __, s__, sprintf } from '~/locale';

const createLengthValidator = (maxLength) => {
  return formValidators.factory(
    sprintf(s__('AICatalog|Input cannot exceed %{value} characters. Please shorten your input.'), {
      value: maxLength,
    }),
    (value) => value.length <= maxLength,
  );
};

export default {
  components: {
    GlButton,
    GlForm,
    GlFormFields,
    GlFormTextarea,
  },
  props: {
    mode: {
      type: String,
      required: true,
      validator: (mode) => ['edit', 'create'].includes(mode),
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
    name: {
      type: String,
      required: false,
      default: '',
    },
    description: {
      type: String,
      required: false,
      default: '',
    },
    systemPrompt: {
      type: String,
      required: false,
      default: '',
    },
    userPrompt: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      formValues: {
        name: this.name,
        description: this.description,
        systemPrompt: this.systemPrompt,
        userPrompt: this.userPrompt,
      },
    };
  },
  computed: {
    formId() {
      return uniqueId('ai-catalog-agent-create-edit-form-');
    },
    submitButtonText() {
      return this.mode === 'create' ? s__('AICatalog|Create agent') : s__('AICatalog|Save changes');
    },
  },
  methods: {
    handleSubmit() {
      const trimmedFormValues = {
        name: this.formValues.name.trim(),
        description: this.formValues.description.trim(),
        systemPrompt: this.formValues.systemPrompt.trim(),
        userPrompt: this.formValues.userPrompt.trim(),
      };
      this.$emit('submit', trimmedFormValues);
    },
  },
  fields: {
    name: {
      label: `${__('Name')} *`,
      validators: [
        formValidators.required(`${__("Name can't be blank")}.`),
        createLengthValidator(MAX_LENGTH_NAME),
      ],
      inputAttrs: {
        'data-testid': 'agent-form-input-name',
      },
    },
    description: {
      label: `${__('Description')} *`,
      validators: [
        formValidators.required(s__("AICatalog|Description can't be blank.")),
        createLengthValidator(MAX_LENGTH_DESCRIPTION),
      ],
    },
    systemPrompt: {
      label: s__('AICatalog|System Prompt'),
      validators: [createLengthValidator(MAX_LENGTH_PROMPT)],
    },
    userPrompt: {
      label: s__('AICatalog|User Prompt'),
      validators: [createLengthValidator(MAX_LENGTH_PROMPT)],
    },
  },
};
</script>
<template>
  <gl-form :id="formId" class="gl-max-w-lg" @submit.prevent>
    <gl-form-fields
      v-model="formValues"
      :form-id="formId"
      :fields="$options.fields"
      @submit="handleSubmit"
    >
      <template #input(description)="{ id, input, value, blur, validation }">
        <gl-form-textarea
          :id="id"
          :no-resize="false"
          :state="validation.state"
          :value="value"
          data-testid="agent-form-textarea-description"
          @blur="blur"
          @update="input"
        />
      </template>
      <template #input(systemPrompt)="{ id, input, value, blur }">
        <gl-form-textarea
          :id="id"
          :no-resize="false"
          :value="value"
          data-testid="agent-form-textarea-system-prompt"
          @blur="blur"
          @update="input"
        />
      </template>
      <template #input(userPrompt)="{ id, input, value, blur }">
        <gl-form-textarea
          :id="id"
          :no-resize="false"
          :value="value"
          data-testid="agent-form-textarea-user-prompt"
          @blur="blur"
          @update="input"
        />
      </template>
    </gl-form-fields>
    <gl-button
      class="js-no-auto-disable"
      type="submit"
      variant="confirm"
      category="primary"
      data-testid="agent-form-submit-button"
      :loading="isLoading"
    >
      {{ submitButtonText }}
    </gl-button>
  </gl-form>
</template>
