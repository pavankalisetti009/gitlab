<script>
import { GlIcon, GlLink, GlButton, GlModalDirective } from '@gitlab/ui';
import { uniqueId } from 'lodash';
import Tracking, { InternalEvents } from '~/tracking';
import UploadBlobModal from '~/repository/components/upload_blob_modal.vue';
import { ICON_TYPE_EMPTY, ICON_TYPE_COMPLETED } from '../constants';

export default {
  name: 'AddCodeActionItem',
  components: {
    GlIcon,
    GlLink,
    GlButton,
    UploadBlobModal,
  },
  directives: {
    GlModal: GlModalDirective,
  },
  mixins: [InternalEvents.mixin(), Tracking.mixin({ category: 'projects:learn_gitlab:show' })],
  inject: ['projectName', 'defaultBranch', 'canPushCode', 'canPushToBranch', 'uploadPath'],
  props: {
    action: {
      type: Object,
      required: true,
    },
  },
  computed: {
    iconName() {
      return this.action.completed ? ICON_TYPE_COMPLETED : ICON_TYPE_EMPTY;
    },
    uploadBlobModalId() {
      return uniqueId('modal-upload-blob');
    },
    canCommitFiles() {
      return this.canPushCode && this.canPushToBranch;
    },
  },
  methods: {
    trackUploadFilesClick() {
      this.trackEvent('click_upload_files_in_get_started');
    },
    handleWebIdeClick() {
      this.track('click_link', { label: this.action.trackLabel });
    },
  },
};
</script>
<template>
  <li class="gl-flex gl-flex-col gl-gap-3">
    <div class="gl-flex gl-items-center gl-gap-3">
      <gl-icon variant="default" :name="iconName" data-testid="action-icon" />

      <span v-if="action.completed" class="gl-display-inline-block gl-line-through">
        {{ action.title }}
      </span>

      <span v-else class="gl-display-inline-block">
        {{ action.title }}
      </span>
    </div>

    <ul v-if="!action.completed" class="gl-flex gl-list-none gl-flex-col gl-gap-3 gl-pl-6">
      <li v-if="canCommitFiles">
        <gl-button
          v-gl-modal="uploadBlobModalId"
          variant="link"
          data-testid="upload-files-button"
          @click="trackUploadFilesClick"
        >
          {{ s__('LearnGitLab|Upload files') }}
        </gl-button>
      </li>
      <li v-if="canCommitFiles">
        <gl-link :href="action.url" target="_blank" @click="handleWebIdeClick">
          {{ s__('LearnGitLab|Open the WebIDE') }}
          <gl-icon name="external-link" />
        </gl-link>
      </li>
    </ul>

    <upload-blob-modal
      v-if="canCommitFiles"
      :modal-id="uploadBlobModalId"
      :commit-message="__('Upload New File')"
      :target-branch="defaultBranch"
      :original-branch="defaultBranch"
      :can-push-code="canPushCode"
      :can-push-to-branch="canPushToBranch"
      :path="uploadPath"
      :upload-path="uploadPath"
    />
  </li>
</template>
