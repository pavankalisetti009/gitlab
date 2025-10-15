<script>
import { GlLink, GlToggle } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import {
  ACTION_ENABLE_SECRET_MANAGER,
  SECRET_MANAGER_STATUS_ACTIVE,
  SECRET_MANAGER_STATUS_INACTIVE,
  SECRET_MANAGER_STATUS_PROVISIONING,
} from 'ee/ci/secrets/constants';
import enableSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/enable_secret_manager.mutation.graphql';
import getSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_secret_manager_status.query.graphql';
import PermissionsSettings from './components/secrets_manager_permissions_settings.vue';

export const POLL_INTERVAL = 2000;

export default {
  name: 'SecretsManagerSettings',
  components: {
    GlLink,
    GlToggle,
    PermissionsSettings,
  },
  provide() {
    const { fullPath, projectId } = this;
    return { fullPath, projectId };
  },
  props: {
    canManageSecretsManager: {
      type: Boolean,
      required: true,
    },
    fullPath: {
      type: String,
      required: true,
    },
    projectId: {
      type: Number,
      required: true,
    },
  },
  data() {
    return {
      action: null,
      errorMessage: '',
      secretManagerStatus: SECRET_MANAGER_STATUS_INACTIVE,
    };
  },
  apollo: {
    secretManagerStatus: {
      query: getSecretManagerStatusQuery,
      variables() {
        return {
          projectPath: this.fullPath,
        };
      },
      update({ projectSecretsManager }) {
        const newStatus = projectSecretsManager?.status || SECRET_MANAGER_STATUS_INACTIVE;

        if (newStatus !== SECRET_MANAGER_STATUS_PROVISIONING) {
          this.$apollo.queries.secretManagerStatus.stopPolling();
        }

        if (this.isEnablingSecretsManager && newStatus === SECRET_MANAGER_STATUS_ACTIVE) {
          this.$toast.show(
            s__('SecretsManagerPermissions|Secrets manager has been provisioned for this project.'),
          );
        }

        return newStatus;
      },
      error(e) {
        this.$apollo.queries.secretManagerStatus.stopPolling(POLL_INTERVAL);
        this.errorMessage =
          e.graphQLErrors?.[0]?.message ||
          s__(
            'SecretsManagerPermissions|An error occurred while fetching the secrets manager status.',
          );

        if (this.isEnablingSecretsManager) {
          this.secretManagerStatus = SECRET_MANAGER_STATUS_INACTIVE;
        }
      },
      pollInterval: POLL_INTERVAL,
    },
  },
  computed: {
    isActive() {
      return this.secretManagerStatus === SECRET_MANAGER_STATUS_ACTIVE;
    },
    isEnablingSecretsManager() {
      return this.action === ACTION_ENABLE_SECRET_MANAGER;
    },
    isInactive() {
      return this.secretManagerStatus === SECRET_MANAGER_STATUS_INACTIVE;
    },
    isLoading() {
      return this.$apollo.queries.secretManagerStatus.loading;
    },
    isProvisioning() {
      return this.secretManagerStatus === SECRET_MANAGER_STATUS_PROVISIONING;
    },
    isToggleDisabled() {
      // Note: The logic for disabling the secret manager settings toggle is a work in progress
      // as discussed in this issue https://gitlab.com/gitlab-org/gitlab/-/issues/479992#note_2062593578
      return (
        this.isLoading ||
        this.isProvisioning ||
        this.isActive ||
        this.hasError ||
        !this.canManageSecretsManager
      );
    },
    isToggleLoading() {
      return this.isLoading || this.isProvisioning;
    },
    hasError() {
      return this.errorMessage.length > 0;
    },
  },
  methods: {
    async enableProjectSecretsManager() {
      this.errorMessage = '';
      try {
        const {
          data: {
            projectSecretsManagerInitialize: { errors, projectSecretsManager },
          },
        } = await this.$apollo.mutate({
          mutation: enableSecretManagerMutation,
          variables: {
            projectPath: this.fullPath,
          },
        });

        if (errors.length > 0) {
          throw new Error(errors[0]);
        }

        this.secretManagerStatus = projectSecretsManager?.status || SECRET_MANAGER_STATUS_INACTIVE;
        this.$apollo.queries.secretManagerStatus.startPolling(POLL_INTERVAL);
      } catch (error) {
        this.errorMessage =
          error?.message ||
          s__('SecretsManagerPermissions|An error occurred while enabling the secrets manager.');
      }
    },
    onToggleSecretManager() {
      if (this.isInactive) {
        this.action = ACTION_ENABLE_SECRET_MANAGER;
        this.enableProjectSecretsManager();
      }
    },
  },
  LEARN_MORE_LINK: helpPagePath('ci/secrets/secrets_manager/_index'),
};
</script>

<template>
  <div data-testid="secret-manager">
    <label class="gl-mb-1 gl-mr-3">
      {{ s__('SecretsManagerPermissions|Secrets manager') }}
    </label>
    <p class="gl-mb-2">
      {{
        s__(
          'SecretsManagerPermissions|Enable the secrets manager to securely store and manage sensitive information for this project.',
        )
      }}
      <gl-link :href="$options.LEARN_MORE_LINK">
        {{ __('Learn more.') }}
      </gl-link>
    </p>
    <gl-toggle
      :value="isActive"
      :label="s__('SecretsManagerPermissions|Secrets manager')"
      :disabled="isToggleDisabled"
      :is-loading="isToggleLoading"
      label-position="hidden"
      name="secret_manager_enabled"
      data-testid="secret-manager-toggle"
      @change="onToggleSecretManager"
    />
    <p v-if="hasError" class="gl-mt-2 gl-text-danger" data-testid="secret-manager-error">
      {{ errorMessage }}
    </p>
    <permissions-settings v-if="isActive" :can-manage-secrets-manager="canManageSecretsManager" />
  </div>
</template>
