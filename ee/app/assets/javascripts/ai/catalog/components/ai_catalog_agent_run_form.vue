<script>
import { GlForm, GlFormFields, GlFormTextarea } from '@gitlab/ui';
import { formValidators } from '@gitlab/ui/src/utils';
import { s__, sprintf } from '~/locale';
import { MAX_LENGTH_PROMPT, FORM_ID_TEST_RUN } from 'ee/ai/catalog/constants';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

export default {
  name: 'AiCatalogAgentRunForm',
  components: {
    ClipboardButton,
    GlForm,
    GlFormFields,
    GlFormTextarea,
  },
  mixins: [glFeatureFlagsMixin()],
  data() {
    return {
      formValues: {
        userPrompt: '',
      },
    };
  },
  computed: {
    formId() {
      return FORM_ID_TEST_RUN;
    },
  },
  methods: {
    onSubmit() {
      const transformedValues = {
        userPrompt: this.formValues.userPrompt.trim(),
      };
      this.$emit('submit', transformedValues);
    },
  },
  fields: {
    userPrompt: {
      validators: [
        formValidators.required(s__('AICatalog|Instructions required.')),
        formValidators.factory(
          sprintf(
            s__('AICatalog|Input cannot exceed %{value} characters. Please shorten your input.'),
            {
              value: MAX_LENGTH_PROMPT,
            },
          ),
          (value) => (value?.length || 0) <= MAX_LENGTH_PROMPT,
        ),
      ],
    },
  },
};
</script>

<template>
  <gl-form :id="formId">
    <gl-form-fields
      v-model="formValues"
      :form-id="formId"
      :fields="$options.fields"
      @submit="onSubmit"
    >
      <template #group(userPrompt)-label>
        {{ s__('AICatalog|Instructions') }}
        <div class="label-description">
          <div class="gl-flex gl-justify-between gl-gap-1">
            {{ s__('AICatalog|Ask a question or describe something you want the agent to do.') }}
            <clipboard-button
              :text="formValues.userPrompt"
              :title="s__('AICatalog|Copy instructions')"
              category="secondary"
              size="small"
            />
          </div>
        </div>
      </template>
      <template #input(userPrompt)="{ id, input, value, blur, validation }">
        <gl-form-textarea
          :id="id"
          :no-resize="false"
          :placeholder="
            s__(
              'AICatalog|Please consider my background in... When explaining concepts, use... My preferred format for responses is... Always include...',
            )
          "
          :rows="10"
          :state="validation.state"
          :value="value"
          data-testid="agent-run-form-user-prompt"
          @blur="blur"
          @update="input"
        />
      </template>
    </gl-form-fields>
  </gl-form>
</template>
