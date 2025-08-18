<script>
import { uniqueId } from 'lodash';
import {
  GlAlert,
  GlButton,
  GlForm,
  GlFormFields,
  GlFormRadio,
  GlFormRadioGroup,
  GlFormTextarea,
  GlIcon,
} from '@gitlab/ui';
import {
  MAX_LENGTH_NAME,
  MAX_LENGTH_DESCRIPTION,
  VISIBILITY_LEVEL_PRIVATE,
  VISIBILITY_LEVEL_PUBLIC,
} from 'ee/ai/catalog/constants';
import { __, s__ } from '~/locale';
import { AI_CATALOG_FLOWS_ROUTE } from '../router/constants';
import { createFieldValidators } from '../utils';
import AiCatalogFormButtons from './ai_catalog_form_buttons.vue';
import AiCatalogStepsEditor from './ai_catalog_steps_editor.vue';

const tmpProjectId = 'gid://gitlab/Project/1000000';

export default {
  components: {
    AiCatalogFormButtons,
    AiCatalogStepsEditor,
    GlAlert,
    GlButton,
    GlForm,
    GlFormFields,
    GlFormRadio,
    GlFormRadioGroup,
    GlFormTextarea,
    GlIcon,
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
    errorMessages: {
      type: Array,
      required: false,
      default: () => [],
    },
    initialValues: {
      type: Object,
      required: false,
      default() {
        return {
          projectId: tmpProjectId,
          name: '',
          description: '',
        };
      },
    },
  },

  data() {
    return {
      formValues: {
        ...this.initialValues,
        visibilityLevel: this.initialValues.public
          ? VISIBILITY_LEVEL_PUBLIC
          : VISIBILITY_LEVEL_PRIVATE,
      },
    };
  },
  computed: {
    formId() {
      return uniqueId('ai-catalog-flow-form-');
    },
    isEditMode() {
      return this.mode === 'edit';
    },
    submitButtonText() {
      return this.isEditMode ? s__('AICatalog|Save changes') : s__('AICatalog|Create flow');
    },
    fields() {
      return {
        projectId: {
          label: s__('AICatalog|Project ID'),
          validators: createFieldValidators({
            requiredLabel: s__('AICatalog|Project ID is required.'),
          }),
          inputAttrs: {
            'data-testid': 'flow-form-input-project-id',
            placeholder: tmpProjectId,
            disabled: this.isEditMode,
          },
          groupAttrs: {
            labelDescription: s__(
              'AICatalog|Select a project for your AI flow to be associated with.',
            ),
          },
        },
        name: {
          label: __('Name'),
          validators: createFieldValidators({
            requiredLabel: s__('AICatalog|Name is required.'),
            maxLength: MAX_LENGTH_NAME,
          }),
          inputAttrs: {
            'data-testid': 'flow-form-input-name',
            placeholder: s__('AICatalog|e.g., Research Assistant, Creative Writer, Code Helper'),
          },
          groupAttrs: {
            labelDescription: s__('AICatalog|Choose a memorable name for your AI flow.'),
          },
        },
        description: {
          label: __('Description'),
          validators: createFieldValidators({
            requiredLabel: s__('AICatalog|Description is required.'),
            maxLength: MAX_LENGTH_DESCRIPTION,
          }),
          groupAttrs: {
            labelDescription: s__(
              'AICatalog|Briefly describe what this flow is designed to do and its key capabilities.',
            ),
          },
        },
      };
    },
  },
  watch: {
    errorMessages(newValue) {
      if (newValue.length === 0) {
        return;
      }

      this.$nextTick(() => {
        this.$refs.alertRef?.$el?.scrollIntoView({
          behavior: 'smooth',
          block: 'center',
        });
      });
    },
  },
  methods: {
    handleSubmit() {
      const transformedValues = {
        projectId: this.formValues.projectId.trim(),
        name: this.formValues.name.trim(),
        description: this.formValues.description.trim(),
        public: this.formValues.visibilityLevel === VISIBILITY_LEVEL_PUBLIC,
        steps: [],
      };
      this.$emit('submit', transformedValues);
    },
  },
  indexRoute: AI_CATALOG_FLOWS_ROUTE,
};
</script>
<template>
  <div>
    <gl-alert
      v-show="errorMessages.length"
      ref="alertRef"
      class="gl-mb-3 gl-mt-5"
      variant="danger"
      data-testid="flow-form-error-alert"
      @dismiss="$emit('dismiss-error')"
    >
      <span v-if="errorMessages.length === 1">{{ errorMessages[0] }}</span>
      <ul v-else class="!gl-mb-0 gl-pl-5">
        <li v-for="(errorMessage, index) in errorMessages" :key="index">
          {{ errorMessage }}
        </li>
      </ul>
    </gl-alert>

    <gl-form :id="formId" class="gl-max-w-lg" @submit.prevent>
      <gl-form-fields
        v-model="formValues"
        :form-id="formId"
        :fields="fields"
        @submit="handleSubmit"
      >
        <template #input(description)="{ id, input, value, blur, validation }">
          <gl-form-textarea
            :id="id"
            :no-resize="false"
            :placeholder="
              s__(
                'AICatalog|This flow specializes in... It can help you with... Best suited for...',
              )
            "
            :state="validation.state"
            :value="value"
            data-testid="flow-form-textarea-description"
            @blur="blur"
            @update="input"
          />
        </template>
        <template #input(visibilityLevel)="{ id, input, validation, value }">
          <gl-form-radio-group
            :id="id"
            :state="validation.state"
            :checked="value"
            data-testid="flow-form-radio-group-visibility-level"
            @input="input"
          >
            <gl-form-radio
              v-for="level in visibilityLevels"
              :key="level.value"
              :value="level.value"
              :state="validation.state"
              :data-testid="`${level.value}-radio`"
              class="gl-mb-3"
            >
              <div class="gl-flex gl-items-center gl-gap-2">
                <gl-icon :size="16" :name="level.icon" />
                <span class="gl-font-semibold">
                  {{ level.label }}
                </span>
              </div>
              <template #help>{{ level.text }}</template>
            </gl-form-radio>
          </gl-form-radio-group>
          <gl-alert
            v-if="visibilityLevelAlertText"
            :dismissible="false"
            data-testid="flow-form-visibility-level-alert"
            class="gl-mt-3"
            variant="info"
          >
            {{ visibilityLevelAlertText }}
          </gl-alert>
        </template>
      </gl-form-fields>
      <ai-catalog-steps-editor class="gl-mb-4" />
      <ai-catalog-form-buttons :is-disabled="isLoading" :index-route="$options.indexRoute">
        <gl-button
          class="js-no-auto-disable gl-w-full sm:gl-w-auto"
          type="submit"
          variant="confirm"
          category="primary"
          data-testid="flow-form-submit-button"
          :loading="isLoading"
        >
          {{ submitButtonText }}
        </gl-button>
      </ai-catalog-form-buttons>
    </gl-form>
  </div>
</template>
