<script>
import { uniqueId } from 'lodash';
import { GlButton, GlForm, GlFormFields, GlFormTextarea } from '@gitlab/ui';
import {
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import {
  MAX_LENGTH_NAME,
  MAX_LENGTH_DESCRIPTION,
  VISIBILITY_LEVEL_PRIVATE,
  VISIBILITY_LEVEL_PUBLIC,
  FLOW_VISIBILITY_LEVEL_DESCRIPTIONS,
} from 'ee/ai/catalog/constants';
import { __, s__ } from '~/locale';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { AI_CATALOG_FLOWS_ROUTE } from '../router/constants';
import { createFieldValidators } from '../utils';
import AiCatalogFormButtons from './ai_catalog_form_buttons.vue';
import AiCatalogStepsEditor from './ai_catalog_steps_editor.vue';
import FormProjectDropdown from './form_project_dropdown.vue';
import VisibilityLevelRadioGroup from './visibility_level_radio_group.vue';

export default {
  components: {
    ErrorsAlert,
    AiCatalogFormButtons,
    AiCatalogStepsEditor,
    FormProjectDropdown,
    GlButton,
    GlForm,
    GlFormFields,
    GlFormTextarea,
    VisibilityLevelRadioGroup,
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
    errors: {
      type: Array,
      required: true,
    },
    initialValues: {
      type: Object,
      required: false,
      default() {
        return {
          projectId: null,
          name: '',
          description: '',
          steps: [],
          release: true,
          public: false,
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
      formErrors: [],
    };
  },
  computed: {
    formId() {
      return uniqueId('ai-catalog-flow-form-');
    },
    isEditMode() {
      return this.mode === 'edit';
    },
    allErrors() {
      return [...this.errors, ...this.formErrors];
    },
    submitButtonText() {
      return this.isEditMode ? s__('AICatalog|Save changes') : s__('AICatalog|Create flow');
    },
    fields() {
      const projectIdField = this.isEditMode
        ? {}
        : {
            projectId: {
              label: s__('AICatalog|Project'),
              validators: createFieldValidators({
                requiredLabel: s__('AICatalog|Project is required.'),
              }),
              groupAttrs: {
                labelDescription: s__(
                  'AICatalog|Select a project for your AI flow to be associated with.',
                ),
              },
            },
          };

      return {
        ...projectIdField,
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
        steps: {
          label: s__('AICatalog|Flow nodes'),
          groupAttrs: {
            labelDescription: s__('AICatalog|Nodes run sequentially.'),
          },
        },
        visibilityLevel: {
          label: __('Visibility level'),
          validators: createFieldValidators({
            requiredLabel: s__('AICatalog|Visibility level is required.'),
          }),
          groupAttrs: {
            labelDescription: s__(
              'AICatalog|Choose who can view and interact with this flow after it is published to the public AI catalog.',
            ),
          },
        },
      };
    },
  },
  methods: {
    handleSubmit() {
      const transformedValues = {
        projectId: this.formValues.projectId,
        name: this.formValues.name.trim(),
        description: this.formValues.description.trim(),
        public: this.formValues.visibilityLevel === VISIBILITY_LEVEL_PUBLIC,
        steps: this.formValues.steps.map((s) => ({ agentId: s.id })),
        release: this.initialValues.release,
      };
      this.$emit('submit', transformedValues);
    },
    onError(error) {
      this.formErrors.push(error);
    },
    dismissErrors() {
      this.formErrors = [];
      this.$emit('dismiss-errors');
    },
  },
  indexRoute: AI_CATALOG_FLOWS_ROUTE,
  visibilityLevelTexts: {
    textPrivate: FLOW_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PRIVATE_STRING],
    textPublic: FLOW_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PUBLIC_STRING],
    alertTextPrivate: s__('AICatalog|This flow can be made private if it is not used.'),
    alertTextPublic: s__('AICatalog|A public flow can be made private only if it is not used.'),
  },
};
</script>
<template>
  <div>
    <errors-alert :errors="allErrors" @dismiss="dismissErrors" />
    <gl-form :id="formId" class="gl-max-w-lg" @submit.prevent>
      <gl-form-fields
        v-model="formValues"
        :form-id="formId"
        :fields="fields"
        @submit="handleSubmit"
      >
        <template #input(projectId)="{ id }">
          <form-project-dropdown :id="id" v-model="formValues.projectId" @error="onError" />
        </template>
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
        <template #input(steps)>
          <ai-catalog-steps-editor v-model="formValues.steps" class="gl-mb-4" />
        </template>
        <template #input(visibilityLevel)="{ id, input, validation, value }">
          <visibility-level-radio-group
            :id="id"
            :is-edit-mode="isEditMode"
            :initial-value="initialValues.public"
            :validation-state="validation.state"
            :value="value"
            :texts="$options.visibilityLevelTexts"
            @input="input"
          />
        </template>
      </gl-form-fields>
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
