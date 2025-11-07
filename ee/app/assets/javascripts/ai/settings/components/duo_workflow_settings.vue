<script>
import {
  GlButton,
  GlLink,
  GlModal,
  GlAvatar,
  GlAvatarLink,
  GlLoadingIcon,
  GlBadge,
} from '@gitlab/ui';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { s__, sprintf } from '~/locale';
import axios from '~/lib/utils/axios_utils';
import { createAlert } from '~/alert';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'DuoWorkflowSettings',
  components: {
    GlButton,
    GlLink,
    GlModal,
    GlAvatar,
    GlAvatarLink,
    GlLoadingIcon,
    PageHeading,
    CrudComponent,
    GlBadge,
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
      required: true,
    },
    subtitle: {
      type: String,
      required: false,
      default: null,
    },
    displayPageHeading: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      showConfirmModal: false,
      isLoading: false,
    };
  },
  computed: {
    shouldDisplayPageHeader() {
      return this.displayPageHeading && (this.title || this.subtitle);
    },
    serviceAccountHelpPath() {
      return helpPagePath('user/duo_agent_platform/security');
    },
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
              message: username
                ? sprintf(
                    s__(
                      'AiPowered|Composite identity for GitLab Duo Agent Platform is now on for the instance and the service account (%{accountId}) was created. To use Agent Platform in your groups, you must turn on AI features for specific groups.',
                    ),
                    {
                      accountId: `@${username}`,
                    },
                  )
                : s__(
                    'AiPowered|Composite identity for GitLab Duo Agent Platform is now on for the instance. To use Agent Platform in your groups, you must turn on AI features for specific groups.',
                  ),
              variant: 'success',
            },
          ]);
        })
        .catch((error) => {
          createAlert({
            message:
              error.response?.data?.message ||
              s__('AiPowered|Failed to enable composite identity for GitLab Duo Agent Platform.'),
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
                message: s__(
                  'AiPowered|Composite identity for GitLab Duo Agent Platform has successfully been turned off.',
                ),
                variant: 'success',
              },
            ]);
          }
        })
        .catch((error) => {
          createAlert({
            message:
              error.response?.data?.message ||
              s__('AiPowered|Failed to disable composite identity for GitLab Duo Agent Platform.'),
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
};
</script>

<template>
  <div>
    <page-heading v-if="shouldDisplayPageHeader">
      <template v-if="title" #heading>
        <span class="gl-flex gl-items-center gl-gap-3">
          <span data-testid="duo-settings-page-title">{{ title }}</span>
        </span>
      </template>

      <template v-if="subtitle" #description>
        <span data-testid="duo-settings-page-subtitle">
          {{ subtitle }}
        </span>
      </template>
    </page-heading>

    <crud-component
      :title="s__('AiPowered|GitLab Duo Agent Platform composite identity')"
      :class="{ 'gl-mt-5': shouldDisplayPageHeader }"
      :description="s__('AiPowered|GitLab Duo Agent Platform is an AI-native coding agent.')"
    >
      <template #default>
        <h3 class="gl-mb-3">
          {{ __('Status:') }}
          <gl-badge
            :variant="duoWorkflowEnabled ? 'success' : 'neutral'"
            class="gl-relative gl-bottom-1 gl-text-lg"
            >{{ duoWorkflowEnabled ? __('On') : __('Off') }}</gl-badge
          >
        </h3>

        <template v-if="duoWorkflowEnabled">
          <div class="gl-py-3">
            <div class="gl-flex gl-items-center gl-gap-2" data-testid="service-account">
              <span>{{ __('Account:') }}</span>
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

        <div v-if="duoWorkflowEnabled" class="gl-mb-6">
          <gl-button
            data-testid="disable-workflow-button"
            :disabled="isLoading"
            @click="showDisableConfirmation"
          >
            <gl-loading-icon v-if="isLoading" inline size="sm" class="gl-mr-2" />
            {{ s__('AiPowered|Turn off composite identity for GitLab Duo Agent Platform') }}
          </gl-button>
        </div>

        <div v-else class="gl-mb-6">
          <gl-button
            variant="confirm"
            category="primary"
            data-testid="enable-workflow-button"
            :disabled="isLoading"
            @click="enableWorkflow"
          >
            <gl-loading-icon v-if="isLoading" inline size="sm" class="gl-mr-2" />
            {{ s__('AiPowered|Turn on composite identity for GitLab Duo Agent Platform') }}
          </gl-button>

          <p class="gl-mb-0 gl-mt-3 gl-text-sm">
            {{
              s__(
                'AiPowered|When you turn on composite identity for GitLab Duo Agent Platform, a service account is created.',
              )
            }}
            <gl-link
              :href="serviceAccountHelpPath"
              class="gl-ml-1"
              data-testid="service-account-link"
            >
              {{ s__('AiPowered|What is the Duo Agent Platform composite identity?') }}
            </gl-link>
          </p>
        </div>
      </template>
    </crud-component>

    <gl-modal
      :visible="showConfirmModal"
      :title="
        s__(
          'AiPowered|Are you sure you want to turn off composite identity for GitLab Duo Agent Platform?',
        )
      "
      modal-id="disable-workflow-modal"
      size="sm"
      @primary="disableWorkflow"
      @cancel="hideDisableConfirmation"
      @close="hideDisableConfirmation"
    >
      <p>
        {{
          s__(
            "AiPowered|When you turn off composite identity for the Agent Platform, actions will be attributed to the user's account instead of the GitLab Duo service account. Are you sure you want to proceed?",
          )
        }}
      </p>
      <template #modal-footer>
        <gl-button class="js-cancel" data-testid="cancel-button" @click="hideDisableConfirmation">
          {{ __('Cancel') }}
        </gl-button>
        <gl-button
          variant="danger"
          class="js-danger"
          data-testid="confirm-disable-button"
          @click="disableWorkflow"
        >
          {{ s__('AiPowered|Turn off composite identity') }}
        </gl-button>
      </template>
    </gl-modal>
  </div>
</template>
