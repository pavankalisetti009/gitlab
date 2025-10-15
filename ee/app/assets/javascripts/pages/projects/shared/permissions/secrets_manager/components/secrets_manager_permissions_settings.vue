<script>
import { GlCollapsibleListbox, GlLoadingIcon, GlModal, GlTabs } from '@gitlab/ui';
import { upperFirst } from 'lodash';
import { __, s__, sprintf } from '~/locale';
import { createAlert } from '~/alert';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { ACCESS_LEVELS_INTEGER_TO_STRING } from '~/access_level/constants';
import {
  PERMISSION_CATEGORY_GROUP,
  PERMISSION_CATEGORY_ROLE,
  PERMISSION_CATEGORY_USER,
} from '../constants';
import deleteSecretsPermission from '../graphql/delete_secrets_permission.mutation.graphql';
import secretsPermissionsQuery from '../graphql/secrets_permission.query.graphql';
import PermissionsModal from './secrets_manager_permissions_modal.vue';
import PermissionsTable from './secrets_manager_permissions_table.vue';

export default {
  name: 'SecretsManagerPermissionsSettings',
  components: {
    CrudComponent,
    GlCollapsibleListbox,
    GlLoadingIcon,
    GlModal,
    GlTabs,
    PermissionsModal,
    PermissionsTable,
  },
  inject: ['fullPath'],
  props: {
    canManageSecretsManager: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      isDeletingPermission: false,
      permissions: [],
      permissionToBeDeleted: null,
      selectedPermissionCategory: null,
    };
  },
  apollo: {
    permissions: {
      query: secretsPermissionsQuery,
      variables() {
        return {
          projectPath: this.fullPath,
        };
      },
      update(data) {
        return data.secretPermissions.edges?.map((edge) => edge.node) || [];
      },
      error(error) {
        createAlert({
          message: s__(
            'SecretsManagerPermissions|Failed to fetch secrets manager permissions. Please try again later.',
          ),
          captureError: true,
          error,
        });
      },
    },
  },
  computed: {
    deleteModalDescription() {
      if (!this.permissionToBeDeleted) {
        return '';
      }

      const { id, type, user, group } = this.permissionToBeDeleted;
      const role = ACCESS_LEVELS_INTEGER_TO_STRING[id] || '';
      let principalName = upperFirst(role.toLowerCase());

      if (type === PERMISSION_CATEGORY_USER) {
        principalName = user.name;
      } else if (type === PERMISSION_CATEGORY_GROUP) {
        principalName = group.name;
      }

      return sprintf(
        s__(
          'SecretsManagerPermissions|Are you sure you want to remove permissions for %{principalName}?',
        ),
        { principalName },
      );
    },
    deleteModalOptions() {
      return {
        actionPrimary: {
          text: __('Remove permission'),
          attributes: {
            variant: 'confirm',
            loading: this.isDeletingPermission,
          },
        },
        actionSecondary: {
          text: __('Cancel'),
          attributes: {
            variant: 'default',
          },
        },
      };
    },
    isLoading() {
      return this.$apollo.queries.permissions.loading;
    },
    groupPermissions() {
      return (
        this.permissions.filter(
          (permission) => permission.principal.type === PERMISSION_CATEGORY_GROUP,
        ) || []
      );
    },
    rolePermissions() {
      return (
        this.permissions.filter(
          (permission) => permission.principal.type === PERMISSION_CATEGORY_ROLE,
        ) || []
      );
    },
    showDeleteModal() {
      return this.permissionToBeDeleted !== null;
    },
    userPermissions() {
      return (
        this.permissions.filter(
          (permission) => permission.principal.type === PERMISSION_CATEGORY_USER,
        ) || []
      );
    },
  },
  methods: {
    async deletePermission() {
      this.isDeletingPermission = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: deleteSecretsPermission,
          variables: {
            projectPath: this.fullPath,
            principal: {
              id: Number(this.permissionToBeDeleted.id),
              type: this.permissionToBeDeleted.type,
            },
          },
        });

        const error = data.secretPermissionDelete.errors[0];
        if (error) {
          createAlert({ message: error });
          return;
        }

        this.refetchPermissions();
        this.$toast.show(s__('SecretsManagerPermissions|Permissions for secrets manager removed.'));
      } catch (e) {
        createAlert({
          message: s__(
            'SecretsManagerPermissions|Failed to delete secrets manager permissions. Please try again.',
          ),
          captureError: true,
          error: e,
        });
      } finally {
        this.hideDeleteModal();
        this.isDeletingPermission = false;
      }
    },
    hideDeleteModal() {
      this.permissionToBeDeleted = null;
    },
    openDeleteModal(principal) {
      this.permissionToBeDeleted = principal;
    },
    refetchPermissions() {
      this.$apollo.queries.permissions.refetch();
    },
    resetSelectedPermissionCategory() {
      this.selectedPermissionCategory = null;
    },
  },
  CREATE_OPTIONS: [
    {
      text: __('Users'),
      value: PERMISSION_CATEGORY_USER,
    },
    {
      text: __('Groups'),
      value: PERMISSION_CATEGORY_GROUP,
    },
    {
      text: __('Roles'),
      value: PERMISSION_CATEGORY_ROLE,
    },
  ],
  PERMISSION_CATEGORY_GROUP,
  PERMISSION_CATEGORY_ROLE,
  PERMISSION_CATEGORY_USER,
};
</script>

<template>
  <div>
    <permissions-modal
      :permission-category="selectedPermissionCategory"
      @hide="resetSelectedPermissionCategory"
      @refetch="refetchPermissions"
    />
    <gl-modal
      :visible="showDeleteModal"
      :title="s__('SecretsManagerPermissions|Remove secrets manager permissions?')"
      :action-primary="deleteModalOptions.actionPrimary"
      :action-secondary="deleteModalOptions.actionSecondary"
      modal-id="delete-permission-modal"
      data-testid="delete-permission-modal"
      @primary.prevent="deletePermission"
      @secondary="hideDeleteModal"
      @canceled="hideDeleteModal"
      @hidden="hideDeleteModal"
    >
      <div>
        <p>{{ deleteModalDescription }}</p>
      </div>
    </gl-modal>
    <crud-component
      :title="s__('SecretsManagerPermissions|Secrets manager user permissions')"
      class="gl-mt-5"
    >
      <template #actions>
        <gl-collapsible-listbox
          v-if="canManageSecretsManager"
          v-model="selectedPermissionCategory"
          :items="$options.CREATE_OPTIONS"
          :toggle-text="__('Add')"
          size="small"
        />
      </template>
      <template #default>
        <gl-loading-icon v-if="isLoading" />
        <gl-tabs v-else>
          <permissions-table
            :can-delete="canManageSecretsManager"
            :items="userPermissions"
            :permission-category="$options.PERMISSION_CATEGORY_USER"
            @delete-permission="openDeleteModal"
          />
          <permissions-table
            :can-delete="canManageSecretsManager"
            :items="groupPermissions"
            :permission-category="$options.PERMISSION_CATEGORY_GROUP"
            @delete-permission="openDeleteModal"
          />
          <permissions-table
            :can-delete="canManageSecretsManager"
            :items="rolePermissions"
            :permission-category="$options.PERMISSION_CATEGORY_ROLE"
            @delete-permission="openDeleteModal"
          />
        </gl-tabs>
      </template>
    </crud-component>
  </div>
</template>
