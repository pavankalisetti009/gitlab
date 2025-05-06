<script>
import { getIdFromGraphQLId } from '~/graphql_shared/utils';

import { SIMPLE_BLOB_VIEWER } from '~/blob/components/constants';
import DuoWorkflowAction from 'ee/ai/components/duo_workflow_action.vue';
import CeBlobHeader from '~/blob/components/blob_header.vue';

export default {
  components: {
    DuoWorkflowAction,
    CeBlobHeader,
  },
  inject: {
    showDuoWorkflowAction: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  props: {
    blob: {
      type: Object,
      required: true,
    },
    hideViewerSwitcher: {
      type: Boolean,
      required: false,
      default: false,
    },
    isBinary: {
      type: Boolean,
      required: false,
      default: false,
    },
    activeViewerType: {
      type: String,
      required: false,
      default: SIMPLE_BLOB_VIEWER,
    },
    hasRenderError: {
      type: Boolean,
      required: false,
      default: false,
    },
    showPath: {
      type: Boolean,
      required: false,
      default: true,
    },
    showPathAsLink: {
      type: Boolean,
      required: false,
      default: false,
    },
    overrideCopy: {
      type: Boolean,
      required: false,
      default: false,
    },
    showForkSuggestion: {
      type: Boolean,
      required: false,
      default: false,
    },
    showWebIdeForkSuggestion: {
      type: Boolean,
      required: false,
      default: false,
    },
    projectPath: {
      type: String,
      required: false,
      default: '',
    },
    projectId: {
      type: String,
      required: false,
      default: '',
    },
    showBlameToggle: {
      type: Boolean,
      required: false,
      default: false,
    },
    showBlobSize: {
      type: Boolean,
      required: false,
      default: true,
    },
    editButtonVariant: {
      type: String,
      required: false,
      default: 'confirm',
    },
  },
  computed: {
    projectIdAsNumber() {
      return getIdFromGraphQLId(this.projectId);
    },
    agentPrivileges() {
      return [1, 2, 3, 4, 5];
    },
  },
};
</script>
<template>
  <ce-blob-header v-bind="$props" v-on="$listeners">
    <template #ee-duo-workflow-action>
      <duo-workflow-action
        v-if="showDuoWorkflowAction"
        :project-id="projectIdAsNumber"
        :title="__('Convert to GitLab CI/CD')"
        :hover-message="__('Convert Jenkins to GitLab CI/CD using Duo')"
        goal="Jenkinsfile"
        workflow-definition="convert_to_gitlab_ci"
        :agent-privileges="agentPrivileges"
      />
    </template>

    <template #prepend>
      <slot name="prepend"></slot>
    </template>

    <template #actions>
      <slot name="actions"></slot>
    </template>
  </ce-blob-header>
</template>
