<script>
import DuoWorkflowAction from 'ee/ai/components/duo_workflow_action.vue';
import { relativePathToAbsolute } from '~/lib/utils/url_utility';
import { AGENT_PRIVILEGES } from '~/duo_agent_platform/constants';
import { s__ } from '~/locale';

export default {
  name: 'MrWidgetPipelineDuoAction',
  components: {
    DuoWorkflowAction,
  },
  props: {
    pipeline: {
      type: Object,
      required: true,
    },
    mergeRequestPath: {
      type: String,
      required: true,
    },
    targetProjectFullPath: {
      type: String,
      required: true,
    },
    sourceBranch: {
      type: String,
      required: true,
    },
  },
  computed: {
    getPipelinePath() {
      if (this.pipeline?.path) {
        return relativePathToAbsolute(this.pipeline.path, gon.gitlab_url);
      }
      return null;
    },
    getAdditionalContext() {
      return [
        {
          Category: 'merge_request',
          Content: JSON.stringify({
            url: relativePathToAbsolute(this.mergeRequestPath, gon.gitlab_url),
          }),
        },
        {
          Category: 'pipeline',
          Content: JSON.stringify({
            source_branch: this.sourceBranch,
          }),
        },
      ];
    },
    fixPipelineText() {
      return s__('Pipeline|Fix pipeline with Duo');
    },
  },
  AGENT_PRIVILEGES: [
    AGENT_PRIVILEGES.READ_WRITE_FILES,
    AGENT_PRIVILEGES.READ_ONLY_GITLAB,
    AGENT_PRIVILEGES.READ_WRITE_GITLAB,
    AGENT_PRIVILEGES.USE_GIT,
  ],
};
</script>

<template>
  <div class="gl-pt-2">
    <duo-workflow-action
      workflow-definition="fix_pipeline/v1"
      :goal="getPipelinePath"
      :project-path="targetProjectFullPath"
      :hover-message="fixPipelineText"
      :source-branch="sourceBranch"
      :agent-privileges="$options.AGENT_PRIVILEGES"
      :additional-context="getAdditionalContext"
    >
      {{ fixPipelineText }}
    </duo-workflow-action>
  </div>
</template>
