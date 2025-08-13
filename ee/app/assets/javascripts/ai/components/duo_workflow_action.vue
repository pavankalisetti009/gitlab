<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import getDuoWorkflowStatusCheck from 'ee/ai/graphql/get_duo_workflow_status_check.query.graphql';
import { sprintf, s__, __ } from '~/locale';
import axios from '~/lib/utils/axios_utils';
import { createAlert } from '~/alert';

const FLOW_WEB_ENVIRONMENT = 'web';

export default {
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlButton,
  },
  inject: {
    currentRef: {
      default: null,
      type: String,
    },
  },
  props: {
    projectPath: {
      type: String,
      required: false,
      default: null,
    },
    projectId: {
      type: Number,
      required: true,
    },
    title: {
      type: String,
      required: false,
      default: '',
    },
    hoverMessage: {
      type: String,
      required: false,
      default: '',
    },
    goal: {
      type: String,
      required: true,
    },
    workflowDefinition: {
      type: String,
      required: true,
    },
    agentPrivileges: {
      type: Array,
      required: false,
      default: () => [1, 2],
    },
    duoWorkflowInvokePath: {
      type: String,
      required: true,
    },
    promptValidatorRegex: {
      type: RegExp,
      required: false,
      default: null,
    },
    size: {
      type: String,
      default: 'small',
      required: false,
      validator: (size) => ['small', 'medium', 'large'].includes(size),
    },
  },
  data() {
    return {
      isStartingFlow: false,
      isDuoActionEnabled: false,
    };
  },
  apollo: {
    isDuoActionEnabled: {
      query: getDuoWorkflowStatusCheck,
      variables() {
        return {
          projectPath: this.projectPath,
        };
      },
      skip() {
        return !this.projectPath;
      },
      update(data) {
        return Boolean(data.project?.duoWorkflowStatusCheck?.enabled);
      },
      error(error) {
        createAlert({
          message: error?.message || __('Something went wrong'),
          captureError: true,
          error,
        });
      },
    },
  },
  methods: {
    successAlert(id) {
      return this.projectPath && id
        ? {
            message: sprintf(
              s__(
                `DuoAgentPlatform|Flow started successfully. To view progress, see %{linkStart}Session %{id}%{linkEnd}.`,
              ),
              { id },
            ),
            variant: 'success',
            messageLinks: this.formatMessageLinks(id),
          }
        : {
            message: s__('DuoAgentPlatform|Flow started successfully.'),
            variant: 'success',
            messageLinks: {},
          };
    },
    formatMessageLinks(id) {
      return {
        // Hardcoded for an easier integration with any page at GitLab.
        // https://gitlab.com/gitlab-org/gitlab/-/blob/b50c9e5ad666bab0e45365b2c6994d99407a68d1/ee/app/assets/javascripts/ai/duo_agents_platform/router/index.js#L61
        link: `/${this.projectPath}/-/automate/agent-sessions/${id}`,
      };
    },
    startWorkflow() {
      if (this.promptValidatorRegex && !this.promptValidatorRegex.test(this.goal)) {
        this.$emit('prompt-validation-error', this.goal);
        return;
      }

      const requestData = {
        project_id: this.projectId,
        start_workflow: true,
        goal: this.goal,
        environment: FLOW_WEB_ENVIRONMENT,
        workflow_definition: this.workflowDefinition,
        agent_privileges: this.agentPrivileges,
      };

      if (this.currentRef) {
        requestData.source_branch = this.currentRef;
      }

      this.isStartingFlow = true;

      axios
        .post(this.duoWorkflowInvokePath, requestData)
        .then(({ data }) => {
          this.$emit('agent-flow-started', data);

          createAlert(this.successAlert(data.id));
        })
        .catch((error) => {
          createAlert({
            message: s__('DuoAgentPlatform|Error occurred when starting the flow.'),
            captureError: true,
            error,
          });
        })
        .finally(() => {
          this.isStartingFlow = false;
        });
    },
  },
};
</script>
<template>
  <gl-button
    v-if="isDuoActionEnabled"
    v-gl-tooltip.hover.focus.viewport="{ placement: 'top' }"
    category="primary"
    icon="tanuki-ai"
    :loading="isStartingFlow"
    :title="hoverMessage"
    :size="size"
    data-testid="duo-workflow-action-button"
    @click="startWorkflow"
  >
    {{ title }}
  </gl-button>
</template>
