<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { formatGraphQLError } from 'ee/ci/secrets/utils';
import getProjectSecretsManagerStatusQuery from '../graphql/queries/get_secret_manager_status.query.graphql';
import {
  ACCEPTED_CONTEXTS,
  ENTITY_PROJECT,
  POLL_INTERVAL,
  SECRET_MANAGER_STATUS_ERROR,
  SECRET_MANAGER_STATUS_PROVISIONING,
} from '../constants';

export default {
  name: 'SecretsApp',
  components: {
    GlLoadingIcon,
  },
  props: {
    context: {
      type: String,
      required: true,
      validator: (value) => ACCEPTED_CONTEXTS.includes(value),
    },
    fullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      secretManagerStatus: null,
    };
  },
  apollo: {
    secretManagerStatus: {
      query: getProjectSecretsManagerStatusQuery,
      skip() {
        return !this.isProjectContext;
      },
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update({ projectSecretsManager }) {
        const newStatus = projectSecretsManager?.status;

        if (newStatus !== SECRET_MANAGER_STATUS_PROVISIONING) {
          this.$apollo.queries.secretManagerStatus.stopPolling();
        }

        return newStatus;
      },
      error(e) {
        this.$apollo.queries.secretManagerStatus.stopPolling();
        this.secretManagerStatus = SECRET_MANAGER_STATUS_ERROR;
        createAlert({
          message: formatGraphQLError(e.message),
          captureError: true,
          error: e,
        });
      },
      pollInterval: POLL_INTERVAL,
    },
  },
  computed: {
    isProjectContext() {
      return this.context === ENTITY_PROJECT;
    },
    isProvisioning() {
      return this.secretManagerStatus === SECRET_MANAGER_STATUS_PROVISIONING;
    },
    hasStatusError() {
      return this.secretManagerStatus && this.secretManagerStatus === SECRET_MANAGER_STATUS_ERROR;
    },
  },
  methods: {
    showSecretsToast(message) {
      this.$toast.show(message);
    },
  },
};
</script>
<template>
  <gl-loading-icon
    v-if="isProjectContext && !secretManagerStatus"
    data-testid="secrets-manager-loading-status"
    class="gl-mt-5"
  />
  <div
    v-else-if="isProjectContext && isProvisioning"
    data-testid="secrets-manager-provisioning-text"
    class="gl-mt-5 gl-text-center"
  >
    <div class="gl-flex gl-items-center gl-justify-center">
      <gl-loading-icon class="gl-mr-3 gl-mt-1" />
      <p class="gl-mb-0 gl-inline gl-text-size-h1 gl-font-semibold">
        {{ s__('SecretsManager|Provisioning in progress') }}
      </p>
    </div>
    <p class="gl-mt-4 gl-text-subtle">
      {{
        s__(
          'SecretsManager|Please wait while the secrets manager is provisioned. You can refresh at any time.',
        )
      }}
    </p>
  </div>
  <router-view
    v-else-if="!hasStatusError"
    ref="router-view"
    @show-secrets-toast="showSecretsToast"
  />
</template>
