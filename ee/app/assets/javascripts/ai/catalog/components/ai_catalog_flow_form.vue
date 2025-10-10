<script>
import { uniqueId } from 'lodash';
import { GlButton, GlForm, GlFormFields, GlFormTextarea } from '@gitlab/ui';
import {
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import {
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  MAX_LENGTH_NAME,
  MAX_LENGTH_DESCRIPTION,
  VISIBILITY_LEVEL_PRIVATE,
  VISIBILITY_LEVEL_PUBLIC,
  FLOW_VISIBILITY_LEVEL_DESCRIPTIONS,
} from 'ee/ai/catalog/constants';
import { __, s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { AI_CATALOG_FLOWS_ROUTE, AI_CATALOG_FLOWS_SHOW_ROUTE } from '../router/constants';
import { createFieldValidators } from '../utils';
import AiCatalogFormButtons from './ai_catalog_form_buttons.vue';
import AiCatalogStepsEditor from './ai_catalog_steps_editor.vue';
import AiCatalogFormSidePanel from './ai_catalog_form_side_panel.vue';
import FormFlowDefinition from './form_flow_definition.vue';
import FormFlowType from './form_flow_type.vue';
import FormProjectDropdown from './form_project_dropdown.vue';
import VisibilityLevelRadioGroup from './visibility_level_radio_group.vue';

export default {
  components: {
    ErrorsAlert,
    AiCatalogFormButtons,
    AiCatalogStepsEditor,
    AiCatalogFormSidePanel,
    FormFlowDefinition,
    FormFlowType,
    FormProjectDropdown,
    GlButton,
    GlForm,
    GlFormFields,
    GlFormTextarea,
    VisibilityLevelRadioGroup,
  },
  mixins: [glFeatureFlagsMixin()],
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
          type: AI_CATALOG_TYPE_FLOW,
          name: '',
          description: '',
          definition: '',
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
      isAgentPanelVisible: false,
      activeStepIndex: null,
    };
  },
  computed: {
    formId() {
      return uniqueId('ai-catalog-flow-form-');
    },
    isEditMode() {
      return this.mode === 'edit';
    },
    isFlowsAvailable() {
      return this.glFeatures.aiCatalogFlows;
    },
    isThirdPartyFlowsAvailable() {
      return this.glFeatures.aiCatalogThirdPartyFlows;
    },
    isThirdPartyFlow() {
      return (
        this.isThirdPartyFlowsAvailable &&
        (this.formValues.type === AI_CATALOG_TYPE_THIRD_PARTY_FLOW || !this.isFlowsAvailable)
      );
    },
    allErrors() {
      return [...this.errors, ...this.formErrors];
    },
    submitButtonText() {
      return this.isEditMode ? s__('AICatalog|Save changes') : s__('AICatalog|Create flow');
    },
    cancelRoute() {
      // when navigating from edit or duplicate page, we go back to show page
      if (this.$route.params.id) {
        return {
          name: AI_CATALOG_FLOWS_SHOW_ROUTE,
          params: { id: this.$route.params.id },
        };
      }

      // when navigating from new page, we go back to index page
      return {
        name: AI_CATALOG_FLOWS_ROUTE,
      };
    },
    isPublic() {
      return this.formValues.visibilityLevel === VISIBILITY_LEVEL_PUBLIC;
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
      const configurationField = this.isThirdPartyFlow
        ? {
            definition: {
              label: s__('AICatalog|Configuration'),
              validators: createFieldValidators({
                requiredLabel: s__('AICatalog|Configuration is required.'),
              }),
              groupAttrs: {
                labelDescription: s__(
                  'AICatalog|This YAML configuration file determines the prompts, tools, and capabilities of your flow. Required properties: injectGatewayToken, image, commands',
                ),
              },
            },
          }
        : {
            steps: {
              label: s__('AICatalog|Flow nodes'),
              groupAttrs: {
                labelDescription: s__('AICatalog|Nodes run sequentially.'),
              },
            },
          };

      const itemTypeField =
        this.isFlowsAvailable && this.isThirdPartyFlowsAvailable
          ? {
              type: {
                label: __('Type'),
                groupAttrs: {
                  labelDescription: s__('AICatalog|Select the type of your flow.'),
                },
              },
            }
          : {};

      return {
        ...projectIdField,
        ...itemTypeField,
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
        ...configurationField,
      };
    },
  },
  watch: {
    isThirdPartyFlow(val) {
      if (val) {
        this.resetAgentPanel();
      }
    },
  },
  methods: {
    handleSubmit() {
      const configurationField = this.isThirdPartyFlow
        ? { definition: this.formValues.definition?.trim() }
        : {
            steps: this.formValues.steps?.map((s) => ({
              agentId: s.id,
              pinnedVersionPrefix: s.versionName,
            })),
          };

      const transformedValues = {
        projectId: this.formValues.projectId,
        name: this.formValues.name.trim(),
        description: this.formValues.description.trim(),
        public: this.isPublic,
        release: this.initialValues.release,
        ...configurationField,
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
    openAgentPanel(stepIndex) {
      this.isAgentPanelVisible = true;
      this.activeStepIndex = stepIndex;
    },
    resetAgentPanel() {
      this.isAgentPanelVisible = false;
      this.activeStepIndex = null;
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
    <div class="gl-flex gl-items-stretch gl-gap-8">
      <gl-form :id="formId" @submit.prevent>
        <gl-form-fields
          v-model="formValues"
          :form-id="formId"
          :fields="fields"
          @submit="handleSubmit"
        >
          <template #input(projectId)="{ id }">
            <form-project-dropdown :id="id" v-model="formValues.projectId" @error="onError" />
          </template>
          <template #input(type)="{ id, input, value }">
            <form-flow-type :id="id" :value="value" :disabled="isEditMode" @input="input" />
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
          <template #input(definition)="{ input, value }">
            <form-flow-definition :value="value" @input="input" />
          </template>
          <template #input(steps)>
            <ai-catalog-steps-editor
              :steps="formValues.steps"
              class="gl-mb-4"
              @openAgentPanel="openAgentPanel"
            />
          </template>
        </gl-form-fields>
        <ai-catalog-form-buttons :is-disabled="isLoading" :cancel-route="cancelRoute">
          <gl-button
            class="js-no-auto-disable gl-w-full @sm/panel:gl-w-auto"
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
      <ai-catalog-form-side-panel
        v-show="isAgentPanelVisible"
        v-model="formValues.steps"
        class="gl-grow"
        :active-step-index="activeStepIndex"
        :is-flow-public="isPublic"
        @close="resetAgentPanel"
      />
    </div>
  </div>
</template>
