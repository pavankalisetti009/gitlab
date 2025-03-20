<script>
import CeBlobOverflowMenu from '~/repository/components/header_area/blob_overflow_menu.vue';
import projectInfoQuery from 'ee_else_ce/repository/queries/project_info.query.graphql';
import { DEFAULT_BLOB_INFO } from '~/repository/constants';
import { createAlert } from '~/alert';

export default {
  name: 'EEBlobOverflowMenu',
  components: { CeBlobOverflowMenu },
  inject: ['blobInfo', 'currentRef', 'rootRef'],
  props: {
    projectPath: {
      type: String,
      required: true,
    },
    isBinaryFileType: {
      type: Boolean,
      required: false,
      default: false,
    },
    overrideCopy: {
      type: Boolean,
      required: false,
      default: false,
    },
    isEmptyRepository: {
      type: Boolean,
      required: false,
      default: false,
    },
    isUsingLfs: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    projectInfo: {
      query: projectInfoQuery,
      variables() {
        return {
          projectPath: this.projectPath,
        };
      },
      update({ project }) {
        this.pathLocks = project?.pathLocks || DEFAULT_BLOB_INFO.pathLocks;
        this.userPermissions = project?.userPermissions;
      },
      error() {
        createAlert({ message: this.$options.i18n.fetchError });
      },
    },
  },
  data() {
    return {
      userPermissions: DEFAULT_BLOB_INFO.userPermissions,
      pathLocks: DEFAULT_BLOB_INFO.pathLocks,
    };
  },
  computed: {
    isOnDefaultBranch() {
      return this.currentRef === this.rootRef;
    },
    pathLockedByUser() {
      const pathLock = this.pathLocks?.nodes.find((node) => {
        return node.path === this.blobInfo.path;
      });

      return pathLock ? pathLock.user : null;
    },
    canLock() {
      const { pushCode, downloadCode } = this.userPermissions;
      const currentUsername = window.gon?.current_username;

      if (this.pathLockedByUser && this.pathLockedByUser.username !== currentUsername) {
        return false;
      }

      return pushCode && downloadCode;
    },
    canModifyFile() {
      return !this.isOnDefaultBranch || this.canLock;
    },
    isLocked() {
      return Boolean(this.pathLockedByUser);
    },
  },
  methods: {
    onCopy() {
      this.$emit('onCopy');
    },
  },
};
</script>
<template>
  <ce-blob-overflow-menu
    :project-path="projectPath"
    :is-binary-file-type="isBinaryFileType"
    :override-copy="overrideCopy"
    :is-empty-repository="isEmptyRepository"
    :is-using-lfs="isUsingLfs"
    :ee-can-modify-file="canModifyFile"
    :ee-is-locked="isLocked"
    :ee-can-lock="canLock"
    @copy="onCopy"
  />
</template>
