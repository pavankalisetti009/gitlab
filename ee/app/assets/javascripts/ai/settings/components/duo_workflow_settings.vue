<script>
import {
  GlButton,
  GlLink,
  GlModal,
  GlAvatar,
  GlAvatarLink,
  GlLoadingIcon,
  GlCard,
} from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import axios from '~/lib/utils/axios_utils';
import { createAlert } from '~/alert';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';

export default {
  name: 'DuoWorkflowSettings',
  components: {
    PageHeading,
    GlButton,
    GlLink,
    GlModal,
    GlAvatar,
    GlAvatarLink,
    GlLoadingIcon,
    GlCard,
  },
  inject: [
    'duoWorkflowEnabled',
    'duoWorkflowServiceAccount',
    'duoWorkflowSettingsPath',
    'redirectPath',
    'duoWorkflowDisablePath',
  ],
  props: {
    title: {
      type: String,
      required: false,
      default: __('GitLab Duo'),
    },
    subtitle: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      showConfirmModal: false,
      isLoading: false,
    };
  },
  methods: {
    enableWorkflow() {
      this.isLoading = true;

      axios
        .post(this.duoWorkflowSettingsPath)
        .then(({ data }) => {
          const username = data?.service_account?.username;

          visitUrlWithAlerts(this.redirectPath, [
            {
              id: 'duo-workflow-successfully-enabled',
              message: sprintf(this.$options.i18n.enabledSuccessMessage, {
                accountId: username ? `@${username}` : '',
              }),
              variant: 'success',
            },
          ]);
        })
        .catch((error) => {
          createAlert({
            message: error.response?.data?.message || this.$options.i18n.enableErrorMessage,
            captureError: true,
            error,
          });
          this.isLoading = false;
        });
    },

    disableWorkflow() {
      this.showConfirmModal = false;
      this.isLoading = true;

      axios
        .post(this.duoWorkflowDisablePath)
        .then(({ status }) => {
          if (status === 200) {
            visitUrlWithAlerts(this.redirectPath, [
              {
                id: 'duo-workflow-successfully-disabled',
                message: this.$options.i18n.disabledSuccessMessage,
                variant: 'success',
              },
            ]);
          }
        })
        .catch((error) => {
          createAlert({
            message: error.response?.data?.message || this.$options.i18n.disableErrorMessage,
            captureError: true,
            error,
          });
          this.isLoading = false;
        });
    },

    showDisableConfirmation() {
      this.showConfirmModal = true;
    },
    hideDisableConfirmation() {
      this.showConfirmModal = false;
    },
  },
  i18n: {
    workflowTitle: s__('AiPowered|GitLab Duo Workflow'),
    workflowStatusOn: __('On'),
    workflowStatusOff: __('Off'),
    workflowDescription: s__(
      'AiPowered|Workflow is an AI-powered coding agent in the Visual Studio Code (VS Code) IDE.',
    ),
    turnOnButton: s__('AiPowered|Turn on GitLab Duo Workflow'),
    turnOffButton: s__('AiPowered|Turn off GitLab Duo Workflow'),
    serviceAccountText: s__(
      'AiPowered|When you turn on GitLab Duo Workflow, a service account is created.',
    ),
    serviceAccountLink: s__('AiPowered|What is this service account?'),
    accountLabel: __('Account:'),
    enabledSuccessMessage: s__(
      'AiPowered|GitLab Duo Workflow is now on for the instance and the service account (%{accountId}) was created. To use Workflow in your groups, you must turn on AI features for specific groups.',
    ),
    disabledSuccessMessage: s__('AiPowered|GitLab Duo Workflow has successfully been turned off.'),
    confirmModalTitle: s__('AiPowered|Are you sure you want to turn off GitLab Duo Workflow?'),
    confirmModalMessage: s__(
      'AiPowered|When you turn off Workflow, users can no longer use it to solve coding tasks. Are you sure?',
    ),
    cancelButton: __('Cancel'),
    confirmDisableButton: s__('AiPowered|Turn off Workflow'),
    disableErrorMessage: s__('AiPowered|Failed to disable GitLab Duo Workflow.'),
    enableErrorMessage: s__('AiPowered|Failed to enable GitLab Duo Workflow.'),
  },
};
</script>

<template>
  <div>
    <page-heading>
      <template #heading>
        <span class="gl-flex gl-items-center gl-gap-3">
          <span data-testid="duo-workflow-settings-title">{{ title }}</span>
        </span>
      </template>

      <template #description>
        <span data-testid="duo-workflow-settings-subtitle">
          {{ subtitle }}
        </span>
      </template>
    </page-heading>

    <gl-card
      header-class="gl-bg-transparent gl-border-none gl-pb-0"
      footer-class="gl-bg-transparent gl-border-none gl-flex-end"
      class="gl-mt-5 gl-justify-between"
    >
      <template #default>
        <h2 class="gl-heading-3 gl-mb-3 gl-font-bold">{{ $options.i18n.workflowTitle }}</h2>

        <h3 class="gl-font-lg gl-mb-3">
          {{
            duoWorkflowEnabled ? $options.i18n.workflowStatusOn : $options.i18n.workflowStatusOff
          }}
        </h3>

        <template v-if="duoWorkflowEnabled">
          <div class="gl-border-t gl-py-3">
            <div class="gl-flex gl-items-center gl-gap-2" data-testid="service-account">
              <span>{{ $options.i18n.accountLabel }}</span>
              <gl-avatar-link
                :href="duoWorkflowServiceAccount.webUrl"
                :title="duoWorkflowServiceAccount.name"
                class="js-user-link gl-text-subtle"
                :data-user-id="duoWorkflowServiceAccount.id"
              >
                <gl-avatar
                  :src="duoWorkflowServiceAccount.avatarUrl"
                  :size="24"
                  :entity-name="duoWorkflowServiceAccount.name"
                  class="gl-mr-1"
                />
              </gl-avatar-link>
              <span class="gl-mr-1 gl-font-bold">{{ duoWorkflowServiceAccount.name }}</span>
              <span class="gl-text-gray-500">{{ duoWorkflowServiceAccount.username }}</span>
            </div>
          </div>
        </template>

        <template v-else>
          <div class="gl-border-b gl-py-3">
            <p class="gl-mb-0">{{ $options.i18n.workflowDescription }}</p>
          </div>
        </template>
      </template>

      <template #footer>
        <div v-if="duoWorkflowEnabled">
          <gl-button
            variant="danger"
            data-testid="disable-workflow-button"
            :disabled="isLoading"
            @click="showDisableConfirmation"
          >
            <gl-loading-icon v-if="isLoading" inline size="sm" class="gl-mr-2" />
            {{ $options.i18n.turnOffButton }}
          </gl-button>
        </div>

        <div v-else>
          <gl-button
            variant="confirm"
            category="primary"
            data-testid="enable-workflow-button"
            :disabled="isLoading"
            @click="enableWorkflow"
          >
            <gl-loading-icon v-if="isLoading" inline size="sm" class="gl-mr-2" />
            {{ $options.i18n.turnOnButton }}
          </gl-button>

          <p class="gl-mb-0 gl-mt-5">
            {{ $options.i18n.serviceAccountText }}
            <gl-link href="#" class="gl-ml-1" data-testid="service-account-link">
              {{ $options.i18n.serviceAccountLink }}
            </gl-link>
          </p>
        </div>
      </template>
    </gl-card>

    <gl-modal
      :visible="showConfirmModal"
      :title="$options.i18n.confirmModalTitle"
      modal-id="disable-workflow-modal"
      size="sm"
      @primary="disableWorkflow"
      @cancel="hideDisableConfirmation"
      @close="hideDisableConfirmation"
    >
      <p>{{ $options.i18n.confirmModalMessage }}</p>
      <template #modal-footer>
        <gl-button class="js-cancel" data-testid="cancel-button" @click="hideDisableConfirmation">
          {{ $options.i18n.cancelButton }}
        </gl-button>
        <gl-button
          variant="danger"
          class="js-danger"
          data-testid="confirm-disable-button"
          @click="disableWorkflow"
        >
          {{ $options.i18n.confirmDisableButton }}
        </gl-button>
      </template>
    </gl-modal>
  </div>
</template>
