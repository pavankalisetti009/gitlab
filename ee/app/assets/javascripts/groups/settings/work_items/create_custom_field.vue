<script>
import { GlButton, GlFormGroup, GlFormInput, GlFormSelect, GlModal, GlAlert } from '@gitlab/ui';
import { nextTick } from 'vue';
import { n__, s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createCustomFieldMutation from './create_custom_field.mutation.graphql';

export const FIELD_TYPE_OPTIONS = [
  { value: 'SINGLE_SELECT', text: s__('WorkItem|Single select') },
  { value: 'MULTI_SELECT', text: s__('WorkItem|Multi select') },
  { value: 'NUMBER', text: s__('WorkItem|Number') },
  { value: 'TEXT', text: s__('WorkItem|Text') },
];

export default {
  components: {
    GlButton,
    GlFormGroup,
    GlFormInput,
    GlFormSelect,
    GlModal,
    GlAlert,
  },
  inject: ['fullPath'],
  data() {
    return {
      visible: false,
      fieldTypes: FIELD_TYPE_OPTIONS,
      formData: {
        fieldType: FIELD_TYPE_OPTIONS[0].value,
        fieldName: '',
        selectOptions: [{ value: '' }],
      },
      formState: {
        fieldName: null,
        selectOptions: null,
      },
      mutationError: '',
    };
  },
  computed: {
    isSelect() {
      return ['SINGLE_SELECT', 'MULTI_SELECT'].includes(this.formData.fieldType);
    },
  },
  methods: {
    async addSelectOption() {
      this.formData.selectOptions.push({ value: '' });
      await nextTick();
      this.$refs[`selectOptions${this.formData.selectOptions.length - 1}`][0].$el.focus();
    },
    removeSelectOption(index) {
      this.formData.selectOptions.splice(index, 1);
      this.validateSelectOptions();
    },
    focusNameInput() {
      this.$refs.nameInput.$el.focus();
    },
    validateForm() {
      this.validateFieldName();
      if (this.isSelect) {
        this.validateSelectOptions();
      }
      return Object.values(this.formState).every((state) => state !== false);
    },
    validateFieldName() {
      this.formState.fieldName = this.formData.fieldName.trim() !== '';
    },
    validateSelectOptions() {
      this.formState.selectOptions = this.formData.selectOptions.some(
        (option) => option.value.trim() !== '',
      );
    },
    removeEmptyOptions() {
      this.formData.selectOptions = this.formData.selectOptions.filter((option) =>
        option.value.trim(),
      );
    },
    async saveCustomField() {
      if (!this.validateForm()) {
        return;
      }
      this.removeEmptyOptions();
      this.mutationError = '';
      try {
        const { data } = await this.$apollo.mutate({
          mutation: createCustomFieldMutation,
          variables: {
            groupPath: this.fullPath,
            name: this.formData.fieldName,
            fieldType: this.formData.fieldType,
            selectOptions: this.isSelect ? this.formData.selectOptions : undefined,
          },
        });

        if (data?.customFieldCreate?.errors?.length) {
          throw new Error(data.customFieldCreate.errors[0]);
        }

        this.$emit('created');
        this.visible = false;
      } catch (error) {
        Sentry.captureException(error);
        this.mutationError =
          error.message ||
          s__('WorkItemCustomField|An error occurred while saving the custom field');
      }
    },
    selectOptionsText(item) {
      if (item.selectOptions.length > 0) {
        return n__('%d option', '%d options', item.selectOptions.length);
      }
      return null;
    },
  },
};
</script>

<template>
  <div>
    <gl-button size="small" data-testid="toggle-modal" @click="visible = true">{{
      s__('WorkItem|Create field')
    }}</gl-button>
    <gl-modal
      modal-id="new-work-item-custom-field"
      :visible="visible"
      :title="s__('WorkItem|New custom field')"
      @shown="focusNameInput"
      @hide="visible = false"
    >
      <gl-form-group :label="s__('WorkItemCustomField|Type')" label-for="field-type">
        <gl-form-select
          id="field-type"
          v-model="formData.fieldType"
          :options="fieldTypes"
          width="md"
        />
      </gl-form-group>

      <gl-form-group
        :label="s__('WorkItemCustomField|Name')"
        label-for="field-name"
        data-testid="custom-field-name"
        :invalid-feedback="s__('WorkItemCustomField|Name is required.')"
        :state="formState.fieldName"
      >
        <gl-form-input
          id="field-name"
          ref="nameInput"
          v-model="formData.fieldName"
          width="md"
          :state="formState.fieldName"
          @input="validateFieldName"
        />
      </gl-form-group>

      <gl-form-group
        v-if="isSelect"
        :label="s__('WorkItemCustomField|Options')"
        data-testid="custom-field-options"
        :state="formState.selectOptions"
        :invalid-feedback="s__('WorkItemCustomField|At least one option is required.')"
      >
        <div
          v-for="(selectOption, index) in formData.selectOptions"
          :key="index"
          class="gl-mb-3 gl-flex"
        >
          <gl-form-input
            :ref="`selectOptions${index}`"
            v-model="selectOption.value"
            width="md"
            :data-testid="`select-options-${index}`"
            @input="validateSelectOptions"
          />
          <gl-button
            category="tertiary"
            icon="remove"
            :aria-label="s__('WorkItemCustomField|Remove')"
            :data-testid="`remove-select-option-${index}`"
            @click="removeSelectOption(index)"
          />
        </div>

        <gl-button
          data-testid="add-select-option"
          category="tertiary"
          icon="plus"
          @click="addSelectOption"
          >{{ s__('WorkItemCustomField|Add option') }}</gl-button
        >
      </gl-form-group>

      <gl-alert v-if="mutationError" variant="danger" :dismissible="false" class="gl-mt-5">
        {{ mutationError }}
      </gl-alert>

      <template #modal-footer>
        <gl-button @click="visible = false">{{ __('Cancel') }}</gl-button>
        <gl-button data-testid="save-custom-field" variant="confirm" @click="saveCustomField">{{
          __('Save')
        }}</gl-button>
      </template>
    </gl-modal>
  </div>
</template>
