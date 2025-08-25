<script>
import { uniqueId } from 'lodash';
import {
  GlAlert,
  GlButton,
  GlForm,
  GlFormFields,
  GlFormTextarea,
  GlFormRadioGroup,
  GlFormRadio,
  GlIcon,
  GlTokenSelector,
} from '@gitlab/ui';
import {
  VISIBILITY_LEVEL_LABELS,
  VISIBILITY_TYPE_ICON,
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
} from 'ee/ai/catalog/constants';
import { __, s__ } from '~/locale';
import { AI_CATALOG_AGENTS_ROUTE } from '../router/constants';
import { createFieldValidators } from '../utils';
import aiCatalogBuiltInToolsQuery from '../graphql/queries/ai_catalog_built_in_tools.query.graphql';
import AiCatalogFormButtons from './ai_catalog_form_buttons.vue';
import ErrorsAlert from './errors_alert.vue';
import FormProjectDropdown from './form_project_dropdown.vue';

export default {
  components: {
    ErrorsAlert,
    AiCatalogFormButtons,
    FormProjectDropdown,
    GlAlert,
    GlButton,
    GlForm,
    GlFormFields,
    GlFormRadioGroup,
    GlFormRadio,
    GlFormTextarea,
    GlIcon,
    GlTokenSelector,
  },
  apollo: {
    availableTools: {
      query: aiCatalogBuiltInToolsQuery,
      update: (data) => data.aiCatalogBuiltInTools.nodes.map((t) => ({ id: t.id, name: t.title })),
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
    errorMessages: {
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
          systemPrompt: '',
          userPrompt: '',
          public: false,
          release: true,
          tools: [],
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
    isEditMode() {
      return this.mode === 'edit';
    },
    allErrorMessages() {
      return [...this.errorMessages, ...this.formErrors];
    },
    submitButtonText() {
      return this.isEditMode ? s__('AICatalog|Save changes') : s__('AICatalog|Create agent');
    },
    visibilityLevels() {
      return [
        {
          value: VISIBILITY_LEVEL_PRIVATE,
          label: VISIBILITY_LEVEL_LABELS[VISIBILITY_LEVEL_PRIVATE_STRING],
          text: AGENT_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PRIVATE_STRING],
          icon: VISIBILITY_TYPE_ICON[VISIBILITY_LEVEL_PRIVATE_STRING],
        },
        {
          value: VISIBILITY_LEVEL_PUBLIC,
          label: VISIBILITY_LEVEL_LABELS[VISIBILITY_LEVEL_PUBLIC_STRING],
          text: AGENT_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PUBLIC_STRING],
          icon: VISIBILITY_TYPE_ICON[VISIBILITY_LEVEL_PUBLIC_STRING],
        },
      ];
    },
    visibilityLevelAlertText() {
      if (
        this.isEditMode &&
        this.initialValues.public &&
        this.formValues.visibilityLevel === VISIBILITY_LEVEL_PRIVATE
      ) {
        return s__('AICatalog|This agent can be made private if it is not used.');
      }

      if (
        !this.initialValues.public &&
        this.formValues.visibilityLevel === VISIBILITY_LEVEL_PUBLIC
      ) {
        return s__('AICatalog|A public agent can be made private only if it is not used.');
      }

      return '';
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
                  'AICatalog|Select a project for your AI agent to be associated with.',
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
            'data-testid': 'agent-form-input-name',
            placeholder: s__('AICatalog|e.g., Research Assistant, Creative Writer, Code Helper'),
          },
          groupAttrs: {
            labelDescription: s__('AICatalog|Choose a memorable name for your AI agent.'),
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
              'AICatalog|Briefly describe what this agent is designed to do and its key capabilities.',
            ),
          },
        },
        tools: {
          label: s__('AICatalog|Tools'),
          groupAttrs: {
            optional: true,
            labelDescription: s__('AICatalog|Select tools that this agent will have access to.'),
          },
        },
        systemPrompt: {
          label: s__('AICatalog|System prompt'),
          validators: createFieldValidators({
            requiredLabel: s__('AICatalog|System prompt is required.'),
            maxLength: MAX_LENGTH_PROMPT,
          }),
          groupAttrs: {
            labelDescription: s__(
              "AICatalog|Define the agent's personality, expertise, and behavioral guidelines. This shapes how the agent responds and approaches tasks.",
            ),
          },
        },
        userPrompt: {
          label: s__('AICatalog|User prompt'),
          validators: createFieldValidators({
            requiredLabel: s__('AICatalog|User prompt is required.'),
            maxLength: MAX_LENGTH_PROMPT,
          }),
          groupAttrs: {
            labelDescription: s__(
              'AICatalog|Provide default instructions or context that will be included with every user interaction.',
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
              'AICatalog|Choose who can view and interact with this agent after it is published to the public AI catalog.',
            ),
          },
        },
      };
    },
    filteredAvailableTools() {
      return this.availableTools.filter((tool) =>
        tool.name.toLowerCase().includes(this.toolFilter.toLowerCase()),
      );
    },
    selectedTools() {
      return this.formValues.tools.map((toolId) => ({
        id: toolId,
        name: this.availableTools.find((tool) => tool.id === toolId)?.name,
      }));
    },
  },

  methods: {
    handleSubmit() {
      const transformedValues = {
        projectId: this.formValues.projectId,
        name: this.formValues.name.trim(),
        description: this.formValues.description.trim(),
        systemPrompt: this.formValues.systemPrompt.trim(),
        userPrompt: this.formValues.userPrompt.trim(),
        public: this.formValues.visibilityLevel === VISIBILITY_LEVEL_PUBLIC,
        release: this.initialValues.release,
        tools: this.formValues.tools,
      };
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
  },
  indexRoute: AI_CATALOG_AGENTS_ROUTE,
};
</script>

<template>
  <div>
    <errors-alert :error-messages="allErrorMessages" @dismiss="dismissErrors" />
    <gl-form :id="formId" @submit.prevent="">
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
                'AICatalog|This agent specializes in... It can help you with... Best suited for...',
              )
            "
            :state="validation.state"
            :value="value"
            data-testid="agent-form-textarea-description"
            @blur="blur"
            @update="input"
          />
        </template>
        <template #input(systemPrompt)="{ id, input, value, blur, validation }">
          <gl-form-textarea
            :id="id"
            :no-resize="false"
            :placeholder="
              s__(
                'AICatalog|You are an expert in [domain]. Your communication style is [style]. When helping users, you should always... Your key strengths include... You approach problems by...',
              )
            "
            :state="validation.state"
            :value="value"
            data-testid="agent-form-textarea-system-prompt"
            @blur="blur"
            @update="input"
          />
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
            data-testid="agent-form-textarea-user-prompt"
            @blur="blur"
            @update="input"
          />
        </template>
        <template #input(tools)>
          <gl-token-selector
            :selected-tokens="selectedTools"
            :dropdown-items="filteredAvailableTools"
            :placeholder="s__('AICatalog|Search and select tools for this agent.')"
            allow-clear-all
            data-testid="agent-form-token-selector-tools"
            @input="handleToolsInput"
            @text-input="handleToolSearch"
          />
        </template>
        <template #input(visibilityLevel)="{ id, input, validation, value }">
          <gl-form-radio-group
            :id="id"
            :state="validation.state"
            :checked="value"
            data-testid="agent-form-radio-group-visibility-level"
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
            data-testid="agent-form-visibility-level-alert"
            class="gl-mt-3"
            variant="info"
          >
            {{ visibilityLevelAlertText }}
          </gl-alert>
        </template>
      </gl-form-fields>
      <ai-catalog-form-buttons :is-disabled="isLoading" :index-route="$options.indexRoute">
        <gl-button
          class="js-no-auto-disable gl-w-full sm:gl-w-auto"
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
