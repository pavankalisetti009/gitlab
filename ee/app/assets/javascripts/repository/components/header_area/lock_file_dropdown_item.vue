<script>
import { GlDisclosureDropdownItem, GlModal } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { sprintf, __ } from '~/locale';
import projectInfoQuery from 'ee_else_ce/repository/queries/project_info.query.graphql';
import lockPathMutation from '~/repository/mutations/lock_path.mutation.graphql';
import { DEFAULT_BLOB_INFO } from '~/repository/constants';

export default {
  i18n: {
    lock: __('Lock'),
    unlock: __('Unlock'),
    modalTitle: __('Lock file?'),
    actionCancel: __('Cancel'),
    fetchError: __('An error occurred while fetching lock information, please try again.'),
    mutationError: __('An error occurred while editing lock information, please try again.'),
  },
  components: {
    GlDisclosureDropdownItem,
    GlModal,
  },
  props: {
    name: {
      type: String,
      required: true,
    },
    path: {
      type: String,
      required: true,
    },
    projectPath: {
      type: String,
      required: true,
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
      isUpdating: false,
      isModalVisible: false,
      locked: false,
      pathLocks: DEFAULT_BLOB_INFO.pathLocks,
      userPermissions: DEFAULT_BLOB_INFO.userPermissions,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo?.queries.projectInfo.loading;
    },
    lockButtonTitle() {
      return this.isLocked ? this.$options.i18n.unlock : this.$options.i18n.lock;
    },
    lockConfirmText() {
      return sprintf(__('Are you sure you want to %{action} %{name}?'), {
        action: this.lockButtonTitle.toLowerCase(),
        name: this.name,
      });
    },
    lockFileItem() {
      return {
        text: this.lockButtonTitle,
        extraAttrs: {
          disabled: !this.canLock || this.isLoading || this.isUpdating,
        },
      };
    },
    modalActions() {
      return {
        primary: {
          text: this.lockButtonTitle,
          attributes: { variant: 'confirm', 'data-testid': 'confirm-ok-button' },
        },
        cancel: {
          text: this.$options.i18n.actionCancel,
        },
      };
    },
    canLock() {
      const { pushCode, downloadCode } = this.userPermissions;
      const currentUsername = window.gon?.current_username;

      if (this.pathLockedByUser && this.pathLockedByUser.username !== currentUsername) {
        return false;
      }

      return pushCode && downloadCode;
    },
    pathLockedByUser() {
      const pathLock = this.pathLocks?.nodes.find((node) => node.path === this.path);

      return pathLock ? pathLock.user : null;
    },
    isLocked() {
      return Boolean(this.pathLockedByUser);
    },
  },
  watch: {
    isLocked(val) {
      this.locked = val;
    },
  },
  methods: {
    hideModal() {
      this.isModalVisible = false;
    },
    showModal() {
      if (this.canLock) {
        this.isModalVisible = true;
      }
    },
    toggleLock() {
      const locked = !this.locked;
      this.isUpdating = true;
      this.$apollo
        .mutate({
          mutation: lockPathMutation,
          variables: {
            filePath: this.path,
            projectPath: this.projectPath,
            lock: locked,
          },
        })
        .catch((error) => {
          createAlert({ message: this.$options.i18n.mutationError, captureError: true, error });
        })
        .finally(() => {
          this.locked = locked;
          this.isUpdating = false;
        });
    },
  },
};
</script>

<template>
  <div>
    <gl-disclosure-dropdown-item :item="lockFileItem" @action="showModal" />
    <gl-modal
      modal-id="lock-file-modal"
      :visible="isModalVisible"
      :title="$options.i18n.modalTitle"
      :action-primary="modalActions.primary"
      :action-cancel="modalActions.cancel"
      @primary="toggleLock"
      @hide="hideModal"
    >
      <p>
        {{ lockConfirmText }}
      </p>
    </gl-modal>
  </div>
</template>
