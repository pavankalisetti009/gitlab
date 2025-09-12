<script>
import { GlCollapsibleListbox, GlFormTextarea, GlFormGroup } from '@gitlab/ui';
import { createAlert } from '~/alert';
import DuoWorkflowAction from '../../../components/duo_workflow_action.vue';
import AiLegalDisclaimer from './ai_legal_disclaimer.vue';

export default {
  components: {
    GlCollapsibleListbox,
    GlFormTextarea,
    GlFormGroup,
    DuoWorkflowAction,
    AiLegalDisclaimer,
  },
  props: {
    defaultAgentFlowType: {
      type: String,
      required: true,
    },
    projectPath: {
      type: String,
      required: true,
    },
    flows: {
      type: Array,
      required: true,
      default: () => [],
    },
  },
  data() {
    return {
      agentflowType: this.defaultAgentFlowType,
      prompt: '',
    };
  },
  computed: {
    selectedAgentFlowText() {
      return this.selectedAgentFlowItem.text;
    },
    selectedAgentFlowItem() {
      return this.flows.find((option) => option.value === this.agentflowType);
    },
    isStartButtonDisabled() {
      return !this.prompt.trim();
    },
  },
  methods: {
    handleAgentFlowStarted(data) {
      this.$emit('agent-flow-started', data);
    },
    handleValidationError() {
      createAlert({
        message: this.selectedAgentFlowItem.validationErrorMessage,
        captureError: false,
        variant: 'danger',
      });
    },
    onAgentFlowSelect(value) {
      this.agentflowType = value;
    },
  },
};
</script>
<template>
  <div>
    <gl-form-group
      :label="s__('DuoAgentsPlatform|Select a flow')"
      label-for="workflow-selector"
      class="gl-mb-5"
    >
      <gl-collapsible-listbox
        id="workflow-selector"
        :items="flows"
        :selected="agentflowType"
        :toggle-text="selectedAgentFlowText"
        @select="onAgentFlowSelect"
      />
    </gl-form-group>

    <gl-form-group
      :label="s__('DuoAgentsPlatform|Prompt')"
      label-for="prompt-textarea"
      class="gl-mb-5"
    >
      <gl-form-textarea
        id="prompt-textarea"
        v-model="prompt"
        :placeholder="selectedAgentFlowItem.helperText"
        :no-resize="false"
        rows="6"
      />
    </gl-form-group>

    <duo-workflow-action
      :agent-privileges="selectedAgentFlowItem.agentPrivileges"
      :project-path="projectPath"
      :title="s__('DuoAgentsPlatform|Start agent session')"
      :goal="prompt"
      :workflow-definition="selectedAgentFlowItem.value"
      :disabled="isStartButtonDisabled"
      :prompt-validator-regex="selectedAgentFlowItem.promptValidatorRegex"
      variant="confirm"
      size="medium"
      @agent-flow-started="handleAgentFlowStarted"
      @prompt-validation-error="handleValidationError"
    />

    <ai-legal-disclaimer />
  </div>
</template>
