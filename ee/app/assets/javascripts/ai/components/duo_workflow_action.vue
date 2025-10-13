<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import getDuoWorkflowStatusCheck from 'ee/ai/graphql/get_duo_workflow_status_check.query.graphql';
import { sprintf, s__, __ } from '~/locale';
import axios from '~/lib/utils/axios_utils';
import { createAlert } from '~/alert';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { buildApiUrl } from '~/api/api_utils';

const FLOW_WEB_ENVIRONMENT = 'web';

export default {
  name: 'DuoWorkflowAction',
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
      required: true,
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
    variant: {
      type: String,
      default: 'default',
      required: false,
      validator: (variant) => ['default', 'confirm', 'danger', 'link'].includes(variant),
    },
    sourceBranch: {
      type: String,
      required: false,
      default: null,
    },
    additionalContext: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      isStartingFlow: false,
      duoWorkflowData: null,
    };
  },
  computed: {
    duoWorkflowInvokePath() {
      return buildApiUrl(`/api/:version/ai/duo_workflows/workflows`);
    },
    isDuoActionEnabled() {
      return this.duoWorkflowData?.isDuoActionEnabled && this.duoWorkflowData?.projectId;
    },
    projectId() {
      return this.duoWorkflowData?.projectId || null;
    },
  },
  apollo: {
    duoWorkflowData: {
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
        if (data.project) {
          return {
            isDuoActionEnabled:
              Boolean(data.project?.duoWorkflowStatusCheck?.enabled) &&
              Boolean(data.project?.duoWorkflowStatusCheck?.remoteFlowsEnabled),
            projectId: getIdFromGraphQLId(data.project.id),
          };
        }
        return null;
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
        additional_context: this.additionalContext,
      };

      if (this.sourceBranch) {
        requestData.source_branch = this.sourceBranch;
      } else if (this.currentRef) {
        requestData.source_branch = this.currentRef;
      }

      this.isStartingFlow = true;

      axios
        .post(this.duoWorkflowInvokePath, requestData)
        .then(({ data }) => {
          if (data.workload && !data.workload.id && data.workload.message) {
            throw new Error(data.workload.message);
          }

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
    :variant="variant"
    data-testid="duo-workflow-action-button"
    @click="startWorkflow"
    ><slot></slot
  ></gl-button>
</template>
