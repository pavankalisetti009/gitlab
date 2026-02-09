<script>
import { uniqueId } from 'lodash';
import {
  GlButton,
  GlLink,
  GlForm,
  GlFormInput,
  GlFormTextarea,
  GlTokenSelector,
  GlTooltipDirective,
} from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import {
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import {
  MAX_LENGTH_NAME,
  MAX_LENGTH_DESCRIPTION,
  MAX_LENGTH_PROMPT,
  VISIBILITY_LEVEL_PRIVATE,
  VISIBILITY_LEVEL_PUBLIC,
  AGENT_VISIBILITY_LEVEL_DESCRIPTIONS,
  AI_CATALOG_TYPE_AGENT,
  DEFAULT_THIRD_PARTY_FLOW_YML_STRING,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
} from 'ee/ai/catalog/constants';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { __, s__ } from '~/locale';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { AI_CATALOG_AGENTS_ROUTE, AI_CATALOG_AGENTS_SHOW_ROUTE } from '../router/constants';
import aiCatalogBuiltInToolsQuery from '../graphql/queries/ai_catalog_built_in_tools.query.graphql';
import AiCatalogFormButtons from './ai_catalog_form_buttons.vue';
import FormGroup from './form_group.vue';
import FormSection from './form_section.vue';
import FormAgentType from './form_agent_type.vue';
import FormFlowDefinition from './form_flow_definition.vue';
import FormProjectDropdown from './form_project_dropdown.vue';
import VisibilityLevelRadioGroup from './visibility_level_radio_group.vue';

export default {
  components: {
    ErrorsAlert,
    AiCatalogFormButtons,
    FormAgentType,
    FormFlowDefinition,
    FormGroup,
    FormSection,
    FormProjectDropdown,
    GlButton,
    GlLink,
    GlForm,
    GlFormInput,
    GlFormTextarea,
    GlTokenSelector,
    VisibilityLevelRadioGroup,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glAbilitiesMixin(), glFeatureFlagsMixin()],
  inject: {
    projectId: {
      default: null,
    },
    isGlobal: {
      default: false,
    },
  },
  apollo: {
    availableTools: {
      query: aiCatalogBuiltInToolsQuery,
      update: (data) =>
        data.aiCatalogBuiltInTools.nodes.map((t) => ({
          id: t.id,
          name: t.title,
          description: t.description,
        })),
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
          systemPrompt: '', // agent specific
          tools: [], // agent specific
          definition: DEFAULT_THIRD_PARTY_FLOW_YML_STRING, // third_party_flow specific
          public: false,
          itemType: AI_CATALOG_TYPE_AGENT,
        };
      },
    },
  },
  data() {
    return {
      availableTools: [],
      toolFilter: '',
      formValues: {
        ...this.initialValues,
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
      return uniqueId('ai-catalog-agent-form-');
    },
    isThirdPartyFlow() {
      return this.formValues.itemType === AI_CATALOG_TYPE_THIRD_PARTY_FLOW;
    },
    isEditMode() {
      return this.mode === 'edit';
    },
    isCreateThirdPartyFlowsAvailable() {
      return (
        this.glAbilities.createAiCatalogThirdPartyFlow ??
        (this.glFeatures.aiCatalogThirdPartyFlows && this.glFeatures.aiCatalogCreateThirdPartyFlows)
      );
    },
    showTypeSelection() {
      if (this.isEditMode) {
        return (
          this.glAbilities.createAiCatalogThirdPartyFlow ?? this.glFeatures.aiCatalogThirdPartyFlows
        );
      }

      return this.isCreateThirdPartyFlowsAvailable;
    },
    allErrors() {
      return [...this.errors, ...this.formErrors];
    },
    submitButtonText() {
      return this.isEditMode ? s__('AICatalog|Save changes') : s__('AICatalog|Create agent');
    },
    cancelRoute() {
      // when navigating from edit or duplicate page, we go back to show page
      if (this.$route.params.id) {
        return {
          name: AI_CATALOG_AGENTS_SHOW_ROUTE,
          params: { id: this.$route.params.id },
        };
      }

      // when navigating from new page, we go back to index page
      return {
        name: AI_CATALOG_AGENTS_ROUTE,
      };
    },
    filteredAvailableTools() {
      return this.availableTools.filter((tool) =>
        tool.name.toLowerCase().includes(this.toolFilter.toLowerCase()),
      );
    },
    selectedTools() {
      return this.availableTools.filter((tool) => this.formValues.tools.includes(tool.id));
    },
  },
  watch: {
    'formValues.projectId': function validateProjectField() {
      this.$nextTick(() => {
        this.$refs.fieldProject?.validate();
      });
    },
    'formValues.itemType': {
      handler(newItemType) {
        this.$emit('select-item-type', newItemType);
      },
    },
  },
  methods: {
    handleSubmit() {
      const isFormValid = this.validate();
      if (!isFormValid) {
        return;
      }

      const transformedValues = {
        projectId: this.isEditMode ? undefined : this.formValues.projectId,
        name: this.formValues.name.trim(),
        description: this.formValues.description.trim(),
        public: this.formValues.visibilityLevel === VISIBILITY_LEVEL_PUBLIC,
        itemType: this.formValues.itemType,
      };

      if (this.isThirdPartyFlow) {
        transformedValues.definition = this.formValues.definition.trim();
      } else {
        transformedValues.systemPrompt = this.formValues.systemPrompt.trim();
        transformedValues.tools = this.formValues.tools;
      }

      this.$emit('submit', transformedValues);
    },
    handleToolsInput(input) {
      this.formValues.tools = input.map((t) => t.id);
    },
    handleToolSearch(search) {
      this.toolFilter = search;
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
  visibilityLevelTexts: {
    textPrivate: AGENT_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PRIVATE_STRING],
    textPublic: AGENT_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PUBLIC_STRING],
  },
  fields: {
    projectId: {
      id: 'agent-form-project-id',
      label: s__('AICatalog|Managed by'),
      validations: {
        requiredLabel: s__('AICatalog|Project is required.'),
      },
      groupAttrs: {
        labelDescription: s__(
          'AICatalog|Only members of this project can edit or delete this agent.',
        ),
      },
    },
    name: {
      id: 'agent-form-name',
      label: __('Display name'),
      validations: {
        requiredLabel: s__('AICatalog|Name is required.'),
        maxLength: MAX_LENGTH_NAME,
      },
      inputAttrs: {
        'data-testid': 'agent-form-input-name',
        placeholder: s__('AICatalog|Research Assistant, Creative Writer, Code Helper'),
      },
    },
    description: {
      id: 'agent-form-description',
      label: __('Description'),
      validations: {
        requiredLabel: s__('AICatalog|Description is required.'),
        maxLength: MAX_LENGTH_DESCRIPTION,
      },
    },
    itemType: {
      id: 'agent-form-type',
      label: __('Type'),
      groupAttrs: {
        labelDescription: s__(
          'AICatalog|Build a custom agent in GitLab or connect to an AI model provider you already use.',
        ),
      },
    },
    systemPrompt: {
      id: 'agent-form-system-prompt',
      label: s__('AICatalog|System prompt'),
      validations: {
        requiredLabel: s__('AICatalog|System prompt is required.'),
        maxLength: MAX_LENGTH_PROMPT,
      },
      groupAttrs: {
        labelDescription: s__(
          "AICatalog|Define the agent's personality, expertise, and behavior. This changes how the agent solves problems and responds to requests.",
        ),
      },
    },
    visibilityLevel: {
      id: 'agent-form-visibility-level',
      label: __('Visibility'),
      groupAttrs: {
        labelDescription: s__('AICatalog|Choose who can view and interact with this agent.'),
      },
    },
    tools: {
      id: 'agent-form-tools',
      label: s__('AICatalog|Tools'),
      groupAttrs: {
        optional: true,
      },
    },
    definition: {
      id: 'agent-form-configuration',
      label: s__('AICatalog|YAML configuration'),
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
  AI_CATALOG_TYPE_AGENT,
  toolsDocsLink: helpPagePath('user/duo_agent_platform/agents/tools'),
};
</script>

<template>
  <div>
    <errors-alert :errors="allErrors" @dismiss="dismissErrors" />
    <gl-form :id="formId" class="gl-flex gl-flex-col gl-gap-5" @submit.prevent="handleSubmit">
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
                'AICatalog|This agent specializes in... It can help you with... Best suited for...',
              )
            "
            :state="state"
            data-testid="agent-form-textarea-description"
            @blur="blur"
          />
        </form-group>
      </form-section>
      <form-section :title="s__('AICatalog|Visibility & access')">
        <form-group
          v-if="isGlobal"
          ref="fieldProject"
          :field="$options.fields.projectId"
          :field-value="formValues.projectId"
        >
          <form-project-dropdown
            :id="$options.fields.projectId.id"
            v-model="formValues.projectId"
            :disabled="isEditMode"
            @error="onError"
          />
        </form-group>
        <form-group
          :field="$options.fields.visibilityLevel"
          :field-value="formValues.visibilityLevel"
        >
          <visibility-level-radio-group
            :id="$options.fields.visibilityLevel.id"
            v-model="formValues.visibilityLevel"
            :item-type="$options.AI_CATALOG_TYPE_AGENT"
            :texts="$options.visibilityLevelTexts"
          />
        </form-group>
      </form-section>
      <form-section :title="s__('AICatalog|Configuration')">
        <form-group
          v-if="showTypeSelection"
          :field="$options.fields.itemType"
          :field-value="formValues.itemType"
        >
          <form-agent-type v-model="formValues.itemType" :disabled="isEditMode" />
        </form-group>
        <form-group
          v-if="isThirdPartyFlow"
          ref="fieldDefinitionThirdPartyFlow"
          :key="$options.fields.definition.id"
          :field="$options.fields.definition"
          :field-value="formValues.definition"
        >
          <form-flow-definition
            v-model="formValues.definition"
            data-testid="flow-form-definition-third-party-flow"
          />
        </form-group>
        <template v-else>
          <form-group :field="$options.fields.tools" :field-value="formValues.tools">
            <template #label-description>
              <span>{{ s__('AICatalog|Tools are built and maintained by GitLab.') }}</span>
              <gl-link :href="$options.toolsDocsLink" target="_blank">{{
                s__('AICatalog|What are tools?')
              }}</gl-link>
            </template>
            <gl-token-selector
              :id="$options.fields.tools.id"
              :selected-tokens="selectedTools"
              :dropdown-items="filteredAvailableTools"
              :placeholder="s__('AICatalog|Search tools.')"
              allow-clear-all
              data-testid="agent-form-token-selector-tools"
              @input="handleToolsInput"
              @text-input="handleToolSearch"
              @keydown.enter.prevent
            >
              <template #token-content="{ token }">
                <span v-gl-tooltip="token.description">
                  {{ token.name }}
                </span>
              </template>
            </gl-token-selector>
          </form-group>
          <form-group
            #default="{ state, blur }"
            ref="fieldSystemPrompt"
            :field="$options.fields.systemPrompt"
            :field-value="formValues.systemPrompt"
          >
            <gl-form-textarea
              :id="$options.fields.systemPrompt.id"
              v-model="formValues.systemPrompt"
              :no-resize="false"
              :placeholder="
                s__(
                  'AICatalog|You are an expert in [domain]. Your communication style is [style]. When helping users, you should always... Your key strengths include... You approach problems by...',
                )
              "
              :rows="20"
              data-testid="agent-form-textarea-system-prompt"
              :state="state"
              @blur="blur"
            />
          </form-group>
        </template>
      </form-section>
      <ai-catalog-form-buttons :is-disabled="isLoading" :cancel-route="cancelRoute">
        <gl-button
          class="js-no-auto-disable gl-w-full @sm/panel:gl-w-auto"
          type="submit"
          variant="confirm"
          category="primary"
          data-testid="agent-form-submit-button"
          :loading="isLoading"
        >
          {{ submitButtonText }}
        </gl-button>
      </ai-catalog-form-buttons>
    </gl-form>
  </div>
</template>
