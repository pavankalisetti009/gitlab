<script>
import { uniqueId } from 'lodash';
import { GlButton, GlForm, GlFormFields, GlFormTextarea } from '@gitlab/ui';
import { s__ } from '~/locale';
import { MAX_LENGTH_PROMPT } from 'ee/ai/catalog/constants';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import { AI_CATALOG_AGENTS_ROUTE } from '../router/constants';
import { createFieldValidators } from '../utils';
import AiCatalogFormButtons from './ai_catalog_form_buttons.vue';

export default {
  name: 'AiCatalogAgentRunForm',
  components: {
    AiCatalogFormButtons,
    ClipboardButton,
    GlButton,
    GlForm,
    GlFormFields,
    GlFormTextarea,
  },
  props: {
    isSubmitting: {
      type: Boolean,
      required: false,
      default: false,
    },
    aiCatalogAgent: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  data() {
    return {
      formValues: {
        userPrompt: this.aiCatalogAgent.latestVersion?.userPrompt,
      },
    };
  },
  computed: {
    formId() {
      return uniqueId('ai-catalog-agent-run-form-');
    },
  },
  methods: {
    onSubmit() {
      this.$emit('submit', this.formValues);
    },
  },
  fields: {
    userPrompt: {
      validators: createFieldValidators({
        requiredLabel: s__('AICatalog|User Prompt is required.'),
        maxLength: MAX_LENGTH_PROMPT,
      }),
    },
  },
  indexRoute: AI_CATALOG_AGENTS_ROUTE,
};
</script>

<template>
  <gl-form :id="formId" @submit.prevent="onSubmit">
    <gl-form-fields v-model="formValues" :form-id="formId" :fields="$options.fields">
      <template #group(userPrompt)-label>
        {{ s__('AICatalog|User prompt') }}
        <div class="label-description">
          <div class="gl-flex gl-justify-between gl-gap-1">
            {{
              s__('AICatalog|Provide instructions or context that will be included for this run.')
            }}
            <clipboard-button
              :text="formValues.userPrompt"
              :title="s__('AICatalog|Copy user prompt')"
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
    <ai-catalog-form-buttons :is-disabled="isSubmitting" :index-route="$options.indexRoute">
      <gl-button
        class="js-no-auto-disable gl-w-full sm:gl-w-auto"
        type="submit"
        variant="confirm"
        category="primary"
        data-testid="agent-run-form-submit-button"
        icon="play"
        :loading="isSubmitting"
      >
        {{ s__('AICatalog|Run') }}
      </gl-button>
    </ai-catalog-form-buttons>
  </gl-form>
</template>
