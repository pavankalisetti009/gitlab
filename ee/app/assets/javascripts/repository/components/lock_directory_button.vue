<script>
import { GlButton, GlTooltipDirective, GlModal, GlModalDirective } from '@gitlab/ui';
import { sprintf, __ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

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
  data() {
    return {
      canAdminLocks: false,
      canPushCode: false,
      allPathLocks: [],
      pathLock: {},
      user: {
        id: 'gid://gitlab/User/1',
        username: 'root',
        name: __('Administrator'),
        avatarUrl: 'https://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=80',
        webUrl: '/root',
        webPath: '/root',
      },
      isLocked: false,
    };
  },
  computed: {
    showLockButton() {
      return Boolean(this.glFeatures.fileLocks && this.user.id);
    },
    isLoading() {
      return false;
    },
    buttonLabel() {
      return this.isLocked ? __('Unlock') : __('Lock');
    },
    buttonState() {
      return this.isLocked ? 'unlock' : 'lock';
    },
    isDisabled() {
      return false;
    },
    tooltipText() {
      return '';
    },
    modalId() {
      return `lock-directory-modal-${this.path.replaceAll('/', '-')}`;
    },
    modalContent() {
      return sprintf(__('Are you sure you want to %{action} this directory?'), {
        action: this.buttonLabel.toLowerCase(),
      });
    },
  },
  methods: {
    toggleLock() {
      this.isLocked = !this.isLocked;
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
