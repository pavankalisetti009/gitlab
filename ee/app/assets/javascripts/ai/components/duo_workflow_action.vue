<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { __, sprintf } from '~/locale';
import axios from '~/lib/utils/axios_utils';
import { createAlert } from '~/alert';

export default {
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlButton,
  },
  inject: ['duoWorkflowInvokePath'],
  props: {
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
  },
  methods: {
    startWorkflow() {
      const requestData = {
        project_id: this.projectId,
        start_workflow: true,
        goal: this.goal,
        workflow_definition: this.workflowDefinition,
        agent_privileges: this.agentPrivileges,
      };

      axios
        .post(this.duoWorkflowInvokePath, requestData)
        .then(({ data }) => {
          createAlert({
            message: sprintf(
              __(`Workflow started successfully, pipeline: %{pipelineHref}`),
              {
                pipelineHref: `<a href="${encodeURI(data.pipeline.path)}">${data.pipeline.id}</a>`,
              },
              false,
            ),
            captureError: true,
            variant: 'success',
            data,
            renderMessageHTML: true,
          });
        })
        .catch((error) => {
          createAlert({
            message: __('Error occurred when starting the workflow'),
            captureError: true,
            error,
          });
        });
    },
  },
};
</script>
<template>
  <gl-button
    v-gl-tooltip.hover.focus.viewport="{ placement: 'top' }"
    category="primary"
    icon="tanuki-ai"
    :title="hoverMessage"
    size="small"
    data-testid="duo-workflow-action-button"
    @click="startWorkflow"
  >
    {{ title }}
  </gl-button>
</template>
