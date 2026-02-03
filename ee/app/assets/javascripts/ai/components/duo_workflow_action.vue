<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import getDuoWorkflowStatusCheck from 'ee/ai/graphql/get_duo_workflow_status_check.query.graphql';
import getConfiguredFlows from 'ee/ai/graphql/get_configured_flows.query.graphql';
import { eventHub, SHOW_SESSION } from 'ee/ai/events/panel';
import { s__, __ } from '~/locale';
import axios from '~/lib/utils/axios_utils';
import { createAlert } from '~/alert';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { buildApiUrl } from '~/api/api_utils';

const FLOW_WEB_ENVIRONMENT = 'web';
const INIT_ERROR_MESSAGE = __('Something went wrong');

export default {
  name: 'DuoWorkflowAction',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlButton,
  },
  mixins: [glFeatureFlagsMixin()],
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
    workItemId: {
      type: [String, Number],
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
      aiCatalogItemConsumerId: null,
    };
  },
  computed: {
    duoWorkflowInvokePath() {
      return buildApiUrl(`/api/:version/ai/duo_workflows/workflows`);
    },
    isDuoActionEnabled() {
      return (
        this.duoWorkflowData?.isDuoActionEnabled &&
        this.duoWorkflowData?.projectId &&
        this.isFlowEnabledInSettings
      );
    },
    projectId() {
      return this.duoWorkflowData?.projectId || null;
    },
    projectGid() {
      return this.duoWorkflowData?.projectGid || null;
    },
    isFlowEnabledInSettings() {
      if (!this.glFeatures.dapUseFoundationalFlowsSetting) {
        return true;
      }
      return Boolean(this.aiCatalogItemConsumerId);
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
          const { id, duoWorkflowStatusCheck } = data.project;

          return {
            isDuoActionEnabled: this.duoActionEnabledFromStatusCheck(duoWorkflowStatusCheck),
            projectId: getIdFromGraphQLId(id),
            projectGid: id,
          };
        }
        return null;
      },
      error(error) {
        createAlert({
          message: error?.message || INIT_ERROR_MESSAGE,
          captureError: true,
          error,
        });
      },
    },
    aiCatalogItemConsumerId: {
      query: getConfiguredFlows,
      variables() {
        return {
          projectId: this.projectGid,
          foundationalFlowReference: this.workflowDefinition,
        };
      },
      skip() {
        if (!this.glFeatures.dapUseFoundationalFlowsSetting) {
          return true;
        }

        return !this.projectGid || !this.workflowDefinition;
      },
      update(data) {
        const configuredItems = data.aiCatalogConfiguredItems?.nodes || [];
        if (configuredItems.length > 0) {
          return data.aiCatalogConfiguredItems.nodes[0].id;
        }

        return null;
      },
      error(error) {
        createAlert({
          message: error?.message || INIT_ERROR_MESSAGE,
          captureError: true,
          error,
        });
      },
    },
  },
  methods: {
    duoActionEnabledFromStatusCheck(duoWorkflowStatusCheck) {
      if (duoWorkflowStatusCheck) {
        const { enabled, remoteFlowsEnabled, createDuoWorkflowForCiAllowed } =
          duoWorkflowStatusCheck;

        return enabled && remoteFlowsEnabled && createDuoWorkflowForCiAllowed !== false;
      }
      return false;
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

      if (this.glFeatures.dapUseFoundationalFlowsSetting && this.aiCatalogItemConsumerId) {
        requestData.ai_catalog_item_consumer_id = getIdFromGraphQLId(this.aiCatalogItemConsumerId);
      }

      if (this.sourceBranch) {
        requestData.source_branch = this.sourceBranch;
      } else if (this.currentRef) {
        requestData.source_branch = this.currentRef;
      }

      if (this.workItemId) {
        requestData.issue_id = this.workItemId;
      }

      this.isStartingFlow = true;

      axios
        .post(this.duoWorkflowInvokePath, requestData)
        .then(({ data }) => {
          if (data.workload && !data.workload.id && data.workload.message) {
            throw new Error(data.workload.message);
          }

          this.$emit('agent-flow-started', data);

          eventHub.$emit(SHOW_SESSION, data);
        })
        .catch((error) => {
          const errorMessage =
            error.response?.data?.message ||
            s__('DuoAgentPlatform|Error occurred when starting the flow.');

          createAlert({
            message: errorMessage,
            captureError: true,
            error,
            renderMessageHTML: true,
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
