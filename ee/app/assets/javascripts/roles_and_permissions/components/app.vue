<script>
import { GlSprintf, GlLink, GlButton } from '@gitlab/ui';
import { keyBy } from 'lodash';
import { s__ } from '~/locale';
import { ACCESS_LEVEL_MINIMAL_ACCESS_INTEGER, BASE_ROLES } from '~/access_level/constants';
import { createAlert } from '~/alert';
import groupMemberRolesQuery from '../graphql/group_member_roles.query.graphql';
import instanceMemberRolesQuery from '../graphql/instance_member_roles.query.graphql';
import RolesTable from './roles_table.vue';
import DeleteRoleModal from './delete_role_modal.vue';

// keyBy creates an object where the key is the access level integer and the value is the base role object. We use this
// to get the description for a base role.
const BASE_ROLES_BY_ACCESS_LEVEL = keyBy(BASE_ROLES, 'accessLevel');

export default {
  name: 'RolesApp',
  i18n: {
    title: s__('MemberRole|Roles and permissions'),
    description: s__(
      'MemberRole|Manage which actions users can take with %{linkStart}roles and permissions%{linkEnd}.',
    ),
    roleCount: s__(
      `MemberRole|%{rolesStart}Roles:%{rolesEnd} %{customCount} Custom %{defaultCount} Default`,
    ),
    newRoleText: s__('MemberRole|New role'),
    fetchRolesError: s__('MemberRole|Failed to fetch roles.'),
    roleDeletedText: s__('MemberRole|Role successfully deleted.'),
  },
  components: {
    GlSprintf,
    GlLink,
    GlButton,
    RolesTable,
    DeleteRoleModal,
  },
  inject: ['documentationPath', 'groupFullPath', 'newRolePath'],
  data() {
    return {
      rolesData: null,
      roleToDelete: null,
    };
  },
  apollo: {
    rolesData: {
      query() {
        return this.groupFullPath ? groupMemberRolesQuery : instanceMemberRolesQuery;
      },
      variables() {
        return this.groupFullPath ? { fullPath: this.groupFullPath } : {};
      },
      update(data) {
        return this.groupFullPath ? data.group : data;
      },
      error() {
        createAlert({ message: this.$options.i18n.fetchRolesError, dismissible: false });
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.rolesData.loading;
    },
    defaultRoles() {
      // Don't show the Minimal Access role (business requirement) and add the description to each role (backend doesn't
      // have descriptions for default roles).
      return (this.rolesData?.standardRoles.nodes || [])
        .filter((role) => role.accessLevel > ACCESS_LEVEL_MINIMAL_ACCESS_INTEGER)
        .map((role) => ({
          ...role,
          description: BASE_ROLES_BY_ACCESS_LEVEL[role.accessLevel].description,
        }));
    },
    customRoles() {
      return this.rolesData?.memberRoles.nodes || [];
    },
    roles() {
      return [...this.defaultRoles, ...this.customRoles];
    },
  },
  methods: {
    processRoleDeletion() {
      this.roleToDelete = null;
      this.$toast.show(this.$options.i18n.roleDeletedText);
      this.$apollo.queries.rolesData.refetch();
    },
  },
};
</script>

<template>
  <section>
    <h2 class="gl-mb-2">{{ $options.i18n.title }}</h2>

    <p class="gl-mb-5 gl-text-gray-700">
      <gl-sprintf :message="$options.i18n.description">
        <template #link="{ content }">
          <gl-link :href="documentationPath" target="_blank">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </p>

    <div class="gl-mb-4 gl-flex gl-flex-wrap gl-items-center gl-justify-between gl-gap-3">
      <span data-testid="role-counts">
        <gl-sprintf :message="$options.i18n.roleCount">
          <template #roles="{ content }">
            <span class="gl-font-bold">{{ content }}</span>
          </template>
          <template #customCount>
            <span class="gl-font-bold">{{ customRoles.length }}</span>
          </template>
          <template #defaultCount>
            <span class="gl-ml-2 gl-font-bold">{{ defaultRoles.length }}</span>
          </template>
        </gl-sprintf>
      </span>

      <gl-button :href="newRolePath" variant="confirm">{{ $options.i18n.newRoleText }}</gl-button>
    </div>

    <roles-table :roles="roles" :busy="isLoading" @delete-role="roleToDelete = $event" />

    <delete-role-modal
      :role="roleToDelete"
      @deleted="processRoleDeletion"
      @close="roleToDelete = null"
    />
  </section>
</template>
