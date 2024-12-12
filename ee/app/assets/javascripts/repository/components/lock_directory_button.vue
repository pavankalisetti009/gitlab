<script>
import { GlButton, GlTooltipDirective, GlModal, GlModalDirective } from '@gitlab/ui';
import { sprintf, __ } from '~/locale';
import { createAlert } from '~/alert';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import currentUserQuery from '~/graphql_shared/queries/current_user.query.graphql';
import projectInfoQuery from 'ee_else_ce/repository/queries/project_info.query.graphql';

export default {
  name: 'LockDirectoryButton',
  i18n: {
    fetchError: __('An error occurred while fetching lock information, please try again.'),
    mutationError: __('An error occurred while editing lock information, please try again.'),
  },
  modal: {
    modalTitle: __('Lock directory?'),
    actionPrimary: {
      text: __('Ok'),
    },
    actionCancel: {
      text: __('Cancel'),
    },
  },
  components: {
    GlButton,
    GlModal,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
    GlModalDirective,
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    projectPath: {
      type: String,
      required: true,
    },
    path: {
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
        this.canAdminLocks = project.userPermissions.adminPathLocks;
        this.canPushCode = project.userPermissions.pushCode;
        this.allPathLocks = project.pathLocks?.nodes?.map((lock) => this.mapPathLocks(lock));
        this.pathLock =
          this.allPathLocks.find(
            (lock) =>
              this.isDownstreamLock(lock) || this.isUpstreamLock(lock) || this.isExactLock(lock),
          ) || {};
      },
      error() {
        this.onFetchError();
      },
    },
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    currentUser: {
      query: currentUserQuery,
      update({ currentUser }) {
        this.user = { ...currentUser };
      },
      error() {
        this.onFetchError();
      },
    },
  },
  data() {
    return {
      canAdminLocks: false,
      canPushCode: false,
      allPathLocks: [],
      pathLock: {},
      user: {},
    };
  },
  computed: {
    showLockButton() {
      return Boolean(this.glFeatures.fileLocks && this.user?.id);
    },
    isLoading() {
      return this.$apollo?.queries.projectInfo.loading;
    },
    isLocked() {
      return this.pathLock.isExactLock || this.pathLock.isUpstreamLock;
    },
    locker() {
      return this.pathLock.user?.name || this.pathLock.user?.username;
    },
    buttonLabel() {
      return this.isLocked ? __('Unlock') : __('Lock');
    },
    buttonState() {
      return this.isLocked ? 'unlock' : 'lock';
    },
    isDisabled() {
      return (
        this.pathLock.isUpstreamLock ||
        this.pathLock.isDownstreamLock ||
        !this.canAdminLocks ||
        !this.canPushCode
      );
    },
    getExactLockTooltip() {
      if (!this.canAdminLocks) {
        return sprintf(__('Locked by %{locker}. You do not have permission to unlock this'), {
          locker: this.locker,
        });
      }
      return this.pathLock.user.id === this.user.id
        ? ''
        : sprintf(__('Locked by %{locker}'), { locker: this.locker });
    },
    getUpstreamLockTooltip() {
      const additionalPhrase = this.canAdminLocks
        ? __('Unlock that directory in order to unlock this')
        : __('You do not have permission to unlock it');
      return sprintf(__('%{locker} has a lock on "%{path}". %{additionalPhrase}'), {
        locker: this.locker,
        path: this.pathLock.path,
        additionalPhrase,
      });
    },
    getDownstreamLockTooltip() {
      const additionalPhrase = this.canAdminLocks
        ? __('Unlock this in order to proceed')
        : __('You do not have permission to unlock it');
      return sprintf(
        __(
          'This directory cannot be locked while %{locker} has a lock on "%{path}". %{additionalPhrase}',
        ),
        {
          locker: this.locker,
          path: this.pathLock.path,
          additionalPhrase,
        },
      );
    },
    tooltipText() {
      if (this.pathLock.isExactLock) {
        return this.getExactLockTooltip;
      }
      if (this.pathLock.isUpstreamLock) {
        return this.getUpstreamLockTooltip;
      }
      if (this.pathLock.isDownstreamLock) {
        return this.getDownstreamLockTooltip;
      }
      if (!this.canPushCode) {
        return __('You do not have permission to lock this');
      }

      return '';
    },
    modalId() {
      return `lock-directory-modal-${this.path.replaceAll('/', '-')}`;
    },
    modalContent() {
      return this.isLocked
        ? __('Are you sure you want to unlock this directory?')
        : __('Are you sure you want to lock this directory?');
    },
  },
  methods: {
    onFetchError() {
      createAlert({ message: this.$options.i18n.fetchError });
    },
    isExactLock(lock) {
      return lock.path === this.path;
    },
    isUpstreamLock(lock) {
      return this.path.startsWith(lock.path) && this.path !== lock.path;
    },
    isDownstreamLock(lock) {
      return lock.path.startsWith(this.path) && this.path !== lock.path;
    },
    mapPathLocks(lock) {
      if (this.isExactLock(lock)) {
        return { ...lock, isExactLock: true };
      }
      if (this.isUpstreamLock(lock)) {
        return { ...lock, isUpstreamLock: true };
      }
      if (this.isDownstreamLock(lock)) {
        return { ...lock, isDownstreamLock: true };
      }
      return lock;
    },
    toggleLock() {
      // will be handled in a following MR
      return true;
    },
  },
};
</script>
<template>
  <span
    v-if="showLockButton"
    class="btn-group"
    :class="{ 'has-tooltip': tooltipText }"
    gl-tooltip
    :title="tooltipText"
  >
    <gl-button
      v-gl-modal-directive="modalId"
      :loading="isLoading"
      :disabled="isDisabled"
      class="path-lock js-path-lock"
      :data-testid="isDisabled ? 'disabled-lock-button' : 'lock-button'"
      :data-state="buttonState"
    >
      {{ buttonLabel }}
    </gl-button>
    <gl-modal
      size="sm"
      :modal-id="modalId"
      :title="$options.modal.modalTitle"
      :action-primary="$options.modal.actionPrimary"
      :action-cancel="$options.modal.actionCancel"
      @primary="toggleLock"
    >
      <p>{{ modalContent }}</p>
    </gl-modal>
  </span>
</template>
