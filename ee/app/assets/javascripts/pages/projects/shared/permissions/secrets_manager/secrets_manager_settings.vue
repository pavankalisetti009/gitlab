<script>
import { GlLink, GlToggle } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import {
  ACCEPTED_CONTEXTS,
  ACTION_ENABLE_SECRET_MANAGER,
  ENTITY_PROJECT,
  ACTION_DISABLE_SECRET_MANAGER,
  SECRET_MANAGER_STATUS_ACTIVE,
  SECRET_MANAGER_STATUS_INACTIVE,
  SECRET_MANAGER_STATUS_PROVISIONING,
  SECRET_MANAGER_STATUS_DEPROVISIONING,
} from 'ee/ci/secrets/constants';
import enableSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/enable_secret_manager.mutation.graphql';
import enableGroupSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/enable_group_secret_manager.mutation.graphql';
import disableSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/disable_secret_manager.mutation.graphql';
import getSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_secret_manager_status.query.graphql';
import getGroupSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_group_secret_manager_status.query.graphql';
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
    context: {
      type: String,
      required: true,
      validator: (value) => ACCEPTED_CONTEXTS.includes(value),
    },
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
      required: false,
      default: null,
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
      query() {
        return this.context === ENTITY_PROJECT
          ? getSecretManagerStatusQuery
          : getGroupSecretManagerStatusQuery;
      },
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        const manager =
          this.context === ENTITY_PROJECT ? data.projectSecretsManager : data.groupSecretsManager;

        const newStatus = manager?.status || SECRET_MANAGER_STATUS_INACTIVE;

        if (this.isEnablingSecretsManager && newStatus === SECRET_MANAGER_STATUS_ACTIVE) {
          this.$apollo.queries.secretManagerStatus.stopPolling();
          this.$toast.show(this.provisionedMessage);
        }

        if (this.isDisablingSecretsManager && newStatus === SECRET_MANAGER_STATUS_INACTIVE) {
          this.$apollo.queries.secretManagerStatus.stopPolling();
          this.$toast.show(
            s__(
              'SecretsManagerPermissions|Secrets manager has been deprovisioned for this project.',
            ),
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
    isDisablingSecretsManager() {
      return this.action === ACTION_DISABLE_SECRET_MANAGER;
    },
    isInactive() {
      return this.secretManagerStatus === SECRET_MANAGER_STATUS_INACTIVE;
    },
    isLoading() {
      return this.$apollo.queries.secretManagerStatus?.loading ?? false;
    },
    isProvisioning() {
      return this.secretManagerStatus === SECRET_MANAGER_STATUS_PROVISIONING;
    },
    isDeprovisioning() {
      return this.secretManagerStatus === SECRET_MANAGER_STATUS_DEPROVISIONING;
    },
    isToggleDisabled() {
      return (
        this.isLoading ||
        this.isProvisioning ||
        this.isDeprovisioning ||
        this.hasError ||
        !this.canManageSecretsManager
      );
    },
    isToggleLoading() {
      return this.isLoading || this.isProvisioning || this.isDeprovisioning;
    },
    hasError() {
      return this.errorMessage.length > 0;
    },
    provisionedMessage() {
      return this.context === ENTITY_PROJECT
        ? s__('SecretsManagerPermissions|Secrets manager has been provisioned for this project.')
        : s__('SecretsManagerPermissions|Secrets manager has been provisioned for this group.');
    },
    descriptionText() {
      return this.context === ENTITY_PROJECT
        ? s__(
            'SecretsManagerPermissions|Enable the secrets manager to securely store and manage sensitive information for this project.',
          )
        : s__(
            'SecretsManagerPermissions|Enable the secrets manager to securely store and manage sensitive information for this group.',
          );
    },
  },
  methods: {
    async enableSecretsManager() {
      this.errorMessage = '';
      try {
        const isProject = this.context === ENTITY_PROJECT;
        const mutation = isProject ? enableSecretManagerMutation : enableGroupSecretManagerMutation;
        const variables = { fullPath: this.fullPath };

        const { data } = await this.$apollo.mutate({
          mutation,
          variables,
        });

        const result = isProject
          ? data.projectSecretsManagerInitialize
          : data.groupSecretsManagerInitialize;
        const { errors } = result;
        const secretsManager = isProject
          ? result.projectSecretsManager
          : result.groupSecretsManager;

        if (errors.length > 0) {
          throw new Error(errors[0]);
        }

        this.secretManagerStatus = secretsManager?.status || SECRET_MANAGER_STATUS_INACTIVE;
        this.$apollo.queries.secretManagerStatus.startPolling(POLL_INTERVAL);
      } catch (error) {
        this.errorMessage =
          error?.message ||
          s__('SecretsManagerPermissions|An error occurred while enabling the secrets manager.');
      }
    },
    async disableProjectSecretsManager() {
      this.errorMessage = '';
      try {
        const {
          data: {
            projectSecretsManagerDeprovision: { errors, projectSecretsManager },
          },
        } = await this.$apollo.mutate({
          mutation: disableSecretManagerMutation,
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
          s__('SecretsManagerPermissions|An error occurred while disabling the secrets manager.');
      }
    },
    onToggleSecretManager() {
      if (this.isInactive) {
        this.action = ACTION_ENABLE_SECRET_MANAGER;
        this.enableSecretsManager();
      } else if (this.isActive && this.context === ENTITY_PROJECT) {
        this.action = ACTION_DISABLE_SECRET_MANAGER;
        this.disableProjectSecretsManager();
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
      {{ descriptionText }}
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
