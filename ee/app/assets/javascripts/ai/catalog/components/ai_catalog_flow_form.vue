<script>
import { uniqueId } from 'lodash';
import { GlButton, GlForm, GlFormInput, GlFormTextarea } from '@gitlab/ui';
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
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { __, s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { AI_CATALOG_FLOWS_ROUTE, AI_CATALOG_FLOWS_SHOW_ROUTE } from '../router/constants';
import AiCatalogFormButtons from './ai_catalog_form_buttons.vue';
import FormFlowDefinition from './form_flow_definition.vue';
import FormFlowType from './form_flow_type.vue';
import FormProjectDropdown from './form_project_dropdown.vue';
import FormGroup from './form_group.vue';
import FormSection from './form_section.vue';
import VisibilityLevelRadioGroup from './visibility_level_radio_group.vue';

export default {
  components: {
    ErrorsAlert,
    AiCatalogFormButtons,
    FormFlowDefinition,
    FormFlowType,
    FormProjectDropdown,
    GlButton,
    GlForm,
    GlFormInput,
    GlFormTextarea,
    FormSection,
    FormGroup,
    VisibilityLevelRadioGroup,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: {
    projectId: {
      default: null,
    },
    isGlobal: {
      default: false,
    },
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
          definition: '',
          release: true,
          public: false,
        };
      },
    },
  },
  data() {
    // Determine the type based on initialValues or feature flags.
    // In case there is no initial value and both feature flags are disabled
    // we are in an invalid state which should not happen at all. Errors expected.
    let type;
    if (this.initialValues.type) {
      type = this.initialValues.type;
    } else if (this.glFeatures.aiCatalogFlows) {
      type = AI_CATALOG_TYPE_FLOW;
    } else if (this.glFeatures.aiCatalogThirdPartyFlows) {
      type = AI_CATALOG_TYPE_THIRD_PARTY_FLOW;
    }

    const isFlowType = type === AI_CATALOG_TYPE_FLOW;
    const { definition, ...initialValuesWithoutDefinition } = this.initialValues;
    return {
      formValues: {
        ...initialValuesWithoutDefinition,
        type,
        definitionFlow: isFlowType ? definition || '' : '',
        definitionThirdPartyFlow: !isFlowType ? definition || '' : '',
        projectId:
          !this.isGlobal && this.projectId
            ? convertToGraphQLId(TYPENAME_PROJECT, this.projectId)
            : this.initialValues.projectId,
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
  },
  methods: {
    handleSubmit() {
      const isFormValid = this.validate();
      if (!isFormValid) {
        return;
      }

      const definition = this.isThirdPartyFlow
        ? this.formValues.definitionThirdPartyFlow
        : this.formValues.definitionFlow;

      const transformedValues = {
        projectId: this.isEditMode ? undefined : this.formValues.projectId,
        name: this.formValues.name.trim(),
        description: this.formValues.description.trim(),
        public: this.formValues.visibilityLevel === VISIBILITY_LEVEL_PUBLIC,
        itemType: this.formValues.type,
        release: this.initialValues.release,
        definition: definition.trim(),
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
    validate() {
      return Object.keys(this.$refs)
        .filter((key) => key.startsWith('field'))
        .reduce((allValid, key) => {
          const field = this.$refs[key];
          if (!field) return allValid;
          const isFieldValid = this.$refs[key].validate();
          return allValid && isFieldValid;
        }, true);
    },
  },
  indexRoute: AI_CATALOG_FLOWS_ROUTE,
  visibilityLevelTexts: {
    textPrivate: FLOW_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PRIVATE_STRING],
    textPublic: FLOW_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PUBLIC_STRING],
    alertTextPrivate: s__('AICatalog|This flow can be made private if it is not used.'),
    alertTextPublic: s__('AICatalog|A public flow can be made private only if it is not used.'),
  },
  fields: {
    projectId: {
      id: 'flow-form-project-id',
      label: s__('AICatalog|Source project'),
      validations: {
        requiredLabel: s__('AICatalog|Project is required.'),
      },
      groupAttrs: {
        labelDescription: s__('AICatalog|Select a project for your AI flow to be associated with.'),
      },
    },
    name: {
      id: 'flow-form-name',
      label: __('Display name'),
      validations: {
        requiredLabel: s__('AICatalog|Name is required.'),
        maxLength: MAX_LENGTH_NAME,
      },
      inputAttrs: {
        'data-testid': 'flow-form-input-name',
        placeholder: s__('AICatalog|e.g., Research Assistant, Creative Writer, Code Helper'),
      },
      groupAttrs: {
        labelDescription: s__('AICatalog|Name your flow.'),
      },
    },
    description: {
      id: 'flow-form-description',
      label: __('Description'),
      validations: {
        requiredLabel: s__('AICatalog|Description is required.'),
        maxLength: MAX_LENGTH_DESCRIPTION,
      },
      groupAttrs: {
        labelDescription: s__('AICatalog|Provide a brief description.'),
      },
    },
    visibilityLevel: {
      id: 'flow-form-visibility-level',
      label: __('Visibility'),
      groupAttrs: {
        labelDescription: s__('AICatalog|Choose who can view and interact with this flow.'),
      },
    },
    type: {
      id: 'flow-form-type',
      label: __('Type'),
      groupAttrs: {
        labelDescription: s__('AICatalog|Select the type of your flow.'),
      },
    },
    definitionFlow: {
      id: 'flow-form-configuration-flow',
      label: s__('AICatalog|Configuration'),
      validations: {
        requiredLabel: s__('AICatalog|Configuration is required.'),
      },
      groupAttrs: {
        labelDescription: s__(
          'AICatalog|This YAML configuration file determines the prompts, tools, and capabilities of your flow. Required properties: version, environment, components, routers, flow, prompts.',
        ),
      },
    },
    definitionThirdPartyFlow: {
      id: 'flow-form-configuration-third-party-flow',
      label: s__('AICatalog|Configuration'),
      validations: {
        requiredLabel: s__('AICatalog|Configuration is required.'),
      },
      groupAttrs: {
        labelDescription: s__(
          'AICatalog|This YAML configuration file determines the prompts, tools, and capabilities of your flow. Required properties: injectGatewayToken, image, commands',
        ),
      },
    },
  },
};
</script>

<template>
  <div>
    <errors-alert :errors="allErrors" @dismiss="dismissErrors" />
    <div class="gl-flex gl-gap-5">
      <gl-form
        :id="formId"
        class="gl-flex gl-grow gl-flex-col gl-gap-5"
        @submit.prevent="handleSubmit"
      >
        <form-section :title="s__('AICatalog|Basic information')">
          <form-group
            #default="{ state, blur }"
            ref="fieldName"
            :field="$options.fields.name"
            :field-value="formValues.name"
          >
            <gl-form-input
              :id="$options.fields.name.id"
              v-model="formValues.name"
              :data-testid="$options.fields.name.inputAttrs['data-testid']"
              :placeholder="$options.fields.name.inputAttrs.placeholder"
              :state="state"
              @blur="blur"
            />
          </form-group>
          <form-group
            #default="{ state, blur }"
            ref="fieldDescription"
            :field="$options.fields.description"
            :field-value="formValues.description"
          >
            <gl-form-textarea
              :id="$options.fields.description.id"
              v-model="formValues.description"
              :no-resize="false"
              :placeholder="
                s__(
                  'AICatalog|This flow specializes in... It can help you with... Best suited for...',
                )
              "
              :state="state"
              data-testid="flow-form-textarea-description"
              @blur="blur"
            />
          </form-group>
        </form-section>
        <form-section :title="s__('AICatalog|Visibility & access')">
          <form-group
            :field="$options.fields.visibilityLevel"
            :field-value="formValues.visibilityLevel"
          >
            <visibility-level-radio-group
              :id="$options.fields.visibilityLevel.id"
              v-model="formValues.visibilityLevel"
              :is-edit-mode="isEditMode"
              :initial-value="initialValues.public"
              :item-type="formValues.type"
              :texts="$options.visibilityLevelTexts"
            />
          </form-group>
          <form-group
            ref="fieldProject"
            :field="$options.fields.projectId"
            :field-value="formValues.projectId"
          >
            <form-project-dropdown
              :id="$options.fields.projectId.id"
              v-model="formValues.projectId"
              :disabled="isEditMode || !isGlobal"
              @error="onError"
            />
          </form-group>
        </form-section>
        <form-section :title="s__('AICatalog|Configuration')">
          <form-group
            v-if="isFlowsAvailable && isThirdPartyFlowsAvailable"
            :field="$options.fields.type"
            :field-value="formValues.type"
          >
            <form-flow-type v-model="formValues.type" :disabled="isEditMode" />
          </form-group>
          <form-group
            v-if="isThirdPartyFlow"
            ref="fieldDefinitionThirdPartyFlow"
            :key="$options.fields.definitionThirdPartyFlow.id"
            :field="$options.fields.definitionThirdPartyFlow"
            :field-value="formValues.definitionThirdPartyFlow"
          >
            <form-flow-definition
              v-model="formValues.definitionThirdPartyFlow"
              data-testid="flow-form-definition-third-party-flow"
            />
          </form-group>
          <form-group
            v-else
            ref="fieldDefinitionFlow"
            :key="$options.fields.definitionFlow.id"
            :field="$options.fields.definitionFlow"
            :field-value="formValues.definitionFlow"
          >
            <form-flow-definition
              v-model="formValues.definitionFlow"
              data-testid="flow-form-definition-flow"
            />
          </form-group>
        </form-section>
      </gl-form>
    </div>
    <ai-catalog-form-buttons :is-disabled="isLoading" :cancel-route="cancelRoute" class="gl-mt-5">
      <gl-button
        :form="formId"
        :loading="isLoading"
        class="js-no-auto-disable gl-w-full @sm/panel:gl-w-auto"
        type="submit"
        variant="confirm"
        category="primary"
        data-testid="flow-form-submit-button"
      >
        {{ submitButtonText }}
      </gl-button>
    </ai-catalog-form-buttons>
  </div>
</template>
