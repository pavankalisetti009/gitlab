<script>
import { GlCollapsibleListbox, GlLoadingIcon, GlTabs } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { createAlert } from '~/alert';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import {
  PERMISSION_CATEGORY_GROUP,
  PERMISSION_CATEGORY_ROLE,
  PERMISSION_CATEGORY_USER,
} from '../constants';
import secretsPermissionsQuery from '../graphql/secrets_permission.query.graphql';
import PermissionsModal from './secrets_manager_permissions_modal.vue';
import PermissionsTable from './secrets_manager_permissions_table.vue';

export default {
  name: 'SecretsManagerPermissionsSettings',
  components: {
    CrudComponent,
    GlCollapsibleListbox,
    GlLoadingIcon,
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
      permissions: [],
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
            'Secrets|Failed to fetch secrets manager permissions. Please try again later.',
          ),
          captureError: true,
          error,
        });
      },
    },
  },
  computed: {
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
    userPermissions() {
      return (
        this.permissions.filter(
          (permission) => permission.principal.type === PERMISSION_CATEGORY_USER,
        ) || []
      );
    },
  },
  methods: {
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
    <crud-component :title="s__('Secrets|Secrets manager user permissions')" class="gl-mt-5">
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
            :items="userPermissions"
            :permission-category="$options.PERMISSION_CATEGORY_USER"
          />
          <permissions-table
            :items="groupPermissions"
            :permission-category="$options.PERMISSION_CATEGORY_GROUP"
          />
          <permissions-table
            :items="rolePermissions"
            :permission-category="$options.PERMISSION_CATEGORY_ROLE"
          />
        </gl-tabs>
      </template>
    </crud-component>
  </div>
</template>
