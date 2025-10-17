<script>
import {
  GlButton,
  GlEmptyState,
  GlIcon,
  GlLabel,
  GlLoadingIcon,
  GlLink,
  GlTableLite,
  GlTooltipDirective,
  GlKeysetPagination,
} from '@gitlab/ui';
import EmptySecretsSvg from '@gitlab/svgs/dist/illustrations/chat-sm.svg?url';
import { helpPagePath } from '~/helpers/help_page_helper';
import { __, s__ } from '~/locale';
import { fetchPolicies } from '~/lib/graphql';
import { createAlert } from '~/alert';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import UserDate from '~/vue_shared/components/user_date.vue';
import { convertEnvironmentScope } from '~/ci/common/private/ci_environments_dropdown';
import getProjectSecretsQuery from '../../graphql/queries/get_project_secrets.query.graphql';
import getProjectSecretsNeedingRotation from '../../graphql/queries/get_project_secrets_needing_rotation.query.graphql';
import {
  DETAILS_ROUTE_NAME,
  EDIT_ROUTE_NAME,
  NEW_ROUTE_NAME,
  PAGE_SIZE,
  SCOPED_LABEL_COLOR,
  SECRET_ROTATION_STATUS,
} from '../../constants';
import SecretDeleteModal from '../secret_delete_modal.vue';
import ActionsCell from './secret_actions_cell.vue';
import SecretsAlertBanner from './secrets_alert_banner.vue';

export default {
  name: 'SecretsTable',
  components: {
    ActionsCell,
    CrudComponent,
    GlButton,
    GlEmptyState,
    GlIcon,
    GlKeysetPagination,
    GlLabel,
    GlLoadingIcon,
    GlLink,
    GlTableLite,
    SecretDeleteModal,
    SecretsAlertBanner,
    TimeAgo,
    UserDate,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    pageSize: {
      type: Number,
      required: false,
      default: PAGE_SIZE,
    },
  },
  data() {
    return {
      secrets: [],
      secretsNeedingRotation: [],
      secretToDelete: '',
      showDeleteModal: false,
      endCursor: null,
      startCursor: null,
      secretsCursor: {},
    };
  },
  apollo: {
    secrets: {
      query: getProjectSecretsQuery,
      variables() {
        return {
          projectPath: this.fullPath,
          limit: this.pageSize,
          ...this.secretsCursor,
        };
      },
      update({ projectSecrets: { edges, pageInfo } }) {
        this.endCursor = pageInfo?.hasNextPage ? pageInfo.endCursor : null;
        this.startCursor = pageInfo?.hasPreviousPage ? pageInfo.startCursor : null;
        return edges.map((e) => e.node) || [];
      },
      error(e) {
        createAlert({
          message: s__(
            'SecretsManager|An error occurred while fetching secrets. Please make sure you have the proper permissions, or try again.',
          ),
          captureError: true,
          error: e,
        });
      },
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
    },
    secretsNeedingRotation: {
      query: getProjectSecretsNeedingRotation,
      variables() {
        return {
          projectPath: this.fullPath,
        };
      },
      update({ projectSecretsNeedingRotation }) {
        return projectSecretsNeedingRotation?.nodes || [];
      },
      error(e) {
        createAlert({
          message: s__(
            'SecretRotation|An error occurred while fetching secrets needing rotation. Please try again.',
          ),
          captureError: true,
          error: e,
        });
      },
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
    },
  },
  computed: {
    showRotationApproachingIcon() {
      return (rotationInfo) => rotationInfo?.status === SECRET_ROTATION_STATUS.approaching;
    },
    showRotationOverdueIcon() {
      return (rotationInfo) => rotationInfo?.status === SECRET_ROTATION_STATUS.overdue;
    },
    hasNextPage() {
      return this.endCursor !== null;
    },
    hasPreviousPage() {
      return this.startCursor !== null;
    },
    isLoading() {
      return this.$apollo.queries.secrets.loading;
    },
    showEmptyState() {
      return this.secrets.length === 0;
    },
    showPagination() {
      return this.hasPreviousPage || this.hasNextPage;
    },
  },
  methods: {
    deleteSecret(secretName) {
      this.secretToDelete = secretName;
      this.showDeleteModal = true;
    },
    getDetailsRoute: (secretName) => ({ name: DETAILS_ROUTE_NAME, params: { secretName } }),
    getEditRoute: (secretName) => ({ name: EDIT_ROUTE_NAME, params: { secretName } }),
    environmentLabelText(environment) {
      const environmentText = convertEnvironmentScope(environment);
      return `${__('env')}::${environmentText}`;
    },
    handleNextPage() {
      this.secretsCursor = {
        after: this.endCursor,
        before: null,
      };
    },
    handlePrevPage() {
      this.secretsCursor = {
        after: null,
        before: this.startCursor,
      };
    },
    hideModal() {
      this.secretToDelete = '';
      this.showDeleteModal = false;
    },
    refetchSecrets() {
      this.$apollo.queries.secrets.refetch();
      this.hideModal();
    },
  },
  fields: [
    {
      key: 'name',
      label: __('Name'),
    },
    {
      key: 'lastAccessed',
      label: __('Last used'),
    },
    {
      key: 'expiration',
      label: __('Expires'),
    },
    {
      key: 'createdAt',
      label: __('Created'),
    },
    {
      key: 'actions',
      label: '',
      tdClass: 'gl-text-right !gl-p-3',
    },
  ],
  EmptySecretsSvg,
  LEARN_MORE_LINK: helpPagePath('ci/secrets/secrets_manager/_index'),
  NEW_ROUTE_NAME,
  SCOPED_LABEL_COLOR,
};
</script>
<template>
  <div>
    <h1 class="page-title gl-text-size-h-display">
      {{ s__('SecretsManager|GitLab Secrets Manager') }}
    </h1>
    <p>
      {{
        s__(
          'SecretsManager|Secrets can be items like API tokens, database credentials, or private keys. Unlike CI/CD variables, secrets must be explicitly requested by a job.',
        )
      }}
      <gl-link :href="$options.LEARN_MORE_LINK">
        {{ __('Learn more.') }}
      </gl-link>
    </p>
    <gl-loading-icon v-if="isLoading" size="lg" class="gl-mt-5" />
    <gl-empty-state
      v-else-if="showEmptyState"
      :title="s__('SecretsManager|Secure your sensitive information')"
      :description="
        s__(
          'SecretsManager|Use the secrets manager to store your sensitive credentials, and then safely use them in your processes.',
        )
      "
      :svg-path="$options.EmptySecretsSvg"
    >
      <template #actions>
        <gl-button :to="$options.NEW_ROUTE_NAME">
          {{ s__('SecretsManager|New secret') }}
        </gl-button>
      </template>
    </gl-empty-state>
    <crud-component v-else :title="s__('SecretsManager|Stored secrets')">
      <secrets-alert-banner
        v-if="secretsNeedingRotation.length"
        :secrets-to-rotate="secretsNeedingRotation"
      />
      <template #actions>
        <gl-button size="small" :to="$options.NEW_ROUTE_NAME" data-testid="new-secret-button">
          {{ s__('SecretsManager|New secret') }}
        </gl-button>
      </template>

      <gl-table-lite :fields="$options.fields" :items="secrets" stacked="md" class="gl-mb-0">
        <template #cell(name)="{ item: { name, branch, environment, rotationInfo } }">
          <div class="gl-block gl-pb-3">
            <router-link data-testid="secret-details-link" :to="getDetailsRoute(name)">
              {{ name }}
            </router-link>
            <gl-icon
              v-if="showRotationApproachingIcon(rotationInfo)"
              v-gl-tooltip
              :title="
                s__('SecretRotation|Rotation reminder: This secret needs to be updated soon.')
              "
              name="warning"
              variant="warning"
              data-testid="rotation-approaching-icon"
            />
            <gl-icon
              v-else-if="showRotationOverdueIcon(rotationInfo)"
              v-gl-tooltip
              :title="s__('SecretRotation|Rotation overdue')"
              name="warning-solid"
              variant="danger"
              data-testid="rotation-overdue-icon"
            />
          </div>

          <gl-label
            :title="environmentLabelText(environment)"
            :background-color="$options.SCOPED_LABEL_COLOR"
            scoped
          />
          <code>
            <gl-icon name="branch" :size="12" class="gl-mr-1" />
            {{ branch }}
          </code>
        </template>
        <template #cell(lastAccessed)="{ item: { lastAccessed } }">
          <time-ago v-if="lastAccessed" :time="lastAccessed" data-testid="secret-last-accessed" />
          <span v-else>{{ __('N/A') }}</span>
        </template>
        <template #cell(expiration)="{ item: { expiration } }">
          <user-date :date="expiration" data-testid="secret-expiration" />
        </template>
        <template #cell(createdAt)="{ item: { createdAt } }">
          <user-date :date="createdAt" data-testid="secret-created-at" />
        </template>
        <template #cell(actions)="{ item: { name } }">
          <actions-cell
            :edit-route="getEditRoute(name)"
            :secret-name="name"
            @delete-secret="deleteSecret"
          />
        </template>
      </gl-table-lite>

      <template v-if="showPagination" #pagination>
        <gl-keyset-pagination
          :has-previous-page="hasPreviousPage"
          :has-next-page="hasNextPage"
          :start-cursor="startCursor"
          :end-cursor="endCursor"
          @prev="handlePrevPage"
          @next="handleNextPage"
        />
      </template>
    </crud-component>
    <secret-delete-modal
      :full-path="fullPath"
      :secret-name="secretToDelete"
      :show-modal="showDeleteModal"
      @hide="hideModal"
      @refetch-secrets="refetchSecrets"
      v-on="$listeners"
    />
  </div>
</template>
