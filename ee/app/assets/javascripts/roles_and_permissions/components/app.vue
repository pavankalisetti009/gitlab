<script>
import { GlSprintf, GlLink, GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { createAlert } from '~/alert';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import groupRolesQuery from '../graphql/group_roles.query.graphql';
import instanceRolesQuery from '../graphql/instance_roles.query.graphql';
import RolesTable from './roles_table.vue';
import DeleteRoleModal from './delete_role_modal.vue';
import RolesExport from './roles_export.vue';

export default {
  name: 'RolesApp',
  i18n: {
    title: s__('MemberRole|Roles and permissions'),
    description: s__(
      'MemberRole|Manage which actions users can take with %{linkStart}roles and permissions%{linkEnd}.',
    ),
    roleCrudTitle: s__('MemberRole|Roles'),
    roleCount: s__(`MemberRole|%{defaultCount} Default %{customCount} Custom`),
    roleCountAdmin: s__(`MemberRole|%{adminCount} Admin`),
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
    RolesExport,
    PageHeading,
    CrudComponent,
  },
  mixins: [glAbilitiesMixin(), glFeatureFlagMixin()],
  props: {
    groupFullPath: {
      type: String,
      required: false,
      default: '',
    },
    newRolePath: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      rolesData: null,
      roleToDelete: null,
    };
  },
  apollo: {
    rolesData: {
      query() {
        return this.groupFullPath ? groupRolesQuery : instanceRolesQuery;
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
      return this.rolesData?.standardRoles.nodes || [];
    },
    customRoles() {
      return this.rolesData?.memberRoles.nodes || [];
    },
    adminRoles() {
      // Only self-managed has admin roles, SaaS does not.
      return this.rolesData?.adminMemberRoles?.nodes || [];
    },
    roles() {
      return [...this.defaultRoles, ...this.customRoles, ...this.adminRoles];
    },
    canExportRoles() {
      // Check that the backend feature is enabled and that the current user can export members.
      return (
        this.glFeatures.membersPermissionsDetailedExport && this.glAbilities.exportGroupMemberships
      );
    },
  },
  methods: {
    processRoleDeletion() {
      this.roleToDelete = null;
      this.$toast.show(this.$options.i18n.roleDeletedText);
      this.$apollo.queries.rolesData.refetch();
    },
  },
  userPermissionsDocPath: helpPagePath('user/permissions'),
};
</script>

<template>
  <section>
    <page-heading :heading="$options.i18n.title">
      <template #description>
        <gl-sprintf :message="$options.i18n.description">
          <template #link="{ content }">
            <gl-link :href="$options.userPermissionsDocPath" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </template>
    </page-heading>

    <crud-component :title="$options.i18n.roleCrudTitle">
      <template #description>
        <span data-testid="role-counts">
          <gl-sprintf :message="$options.i18n.roleCount">
            <template #defaultCount>
              <span class="gl-font-bold">{{ defaultRoles.length }}</span>
            </template>
            <template #customCount>
              <span class="gl-ml-3 gl-font-bold">{{ customRoles.length }}</span>
            </template>
          </gl-sprintf>
          <gl-sprintf v-if="glFeatures.customAdminRoles" :message="$options.i18n.roleCountAdmin">
            <template #adminCount>
              <span class="gl-ml-3 gl-font-bold">{{ adminRoles.length }}</span>
            </template>
          </gl-sprintf>
        </span>
      </template>

      <template #actions>
        <roles-export v-if="canExportRoles" />

        <gl-button v-if="newRolePath" :href="newRolePath" size="small">
          {{ $options.i18n.newRoleText }}
        </gl-button>
      </template>

      <roles-table :roles="roles" :busy="isLoading" @delete-role="roleToDelete = $event" />
    </crud-component>

    <delete-role-modal
      :role="roleToDelete"
      @deleted="processRoleDeletion"
      @close="roleToDelete = null"
    />
  </section>
</template>
