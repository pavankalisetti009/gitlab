<script>
import { GlAlert, GlLink } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import WorkspaceEmptyState from './empty_state.vue';

export const i18n = {
  learnMoreHelpLink: __('Learn more'),
  heading: s__('Workspaces|Workspaces'),
};

const workspacesHelpPath = helpPagePath('user/workspace/index.md');

export default {
  components: {
    GlAlert,
    GlLink,
    WorkspaceEmptyState,
  },
  props: {
    empty: {
      type: Boolean,
      required: true,
    },
    error: {
      type: String,
      required: false,
      default: '',
    },
    newWorkspacePath: {
      type: String,
      required: false,
      default: '',
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  methods: {
    clearError() {
      this.$emit('error', '');
    },
  },
  i18n,
  workspacesHelpPath,
};
</script>
<template>
  <div>
    <gl-alert v-if="error" variant="danger" @dismiss="clearError">
      {{ error }}
    </gl-alert>
    <workspace-empty-state v-if="!loading && empty" :new-workspace-path="newWorkspacePath" />
    <template v-else>
      <div
        data-testid="workspaces-list-header"
        class="gl-display-flex gl-align-items-center gl-justify-content-space-between"
      >
        <div class="gl-display-flex gl-align-items-center">
          <h2>{{ $options.i18n.heading }}</h2>
        </div>
        <div
          class="gl-display-flex gl-align-items-center gl-flex-direction-column gl-md-flex-direction-row"
        >
          <gl-link
            class="gl-mr-5 workspace-list-link gl-hidden gl-sm-display-block"
            :href="$options.workspacesHelpPath"
            >{{ $options.i18n.learnMoreHelpLink }}</gl-link
          >
          <slot name="header"></slot>
        </div>
      </div>
      <slot name="workspaces-list"></slot>
    </template>
  </div>
</template>
