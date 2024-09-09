<script>
import { GlLoadingIcon, GlSprintf, GlLink, GlButton, GlIcon, GlAlert } from '@gitlab/ui';
import { s__, n__ } from '~/locale';
import groupMemberRolesQuery from '../graphql/group_member_roles.query.graphql';
import instanceMemberRolesQuery from '../graphql/instance_member_roles.query.graphql';
import CustomRolesEmptyState from './custom_roles_empty_state.vue';
import RolesTable from './roles_table.vue';
import DeleteRoleModal from './delete_role_modal.vue';

export default {
  name: 'RolesApp',
  i18n: {
    title: s__('MemberRole|Custom roles'),
    description: s__(
      'MemberRole|You can create a custom role by adding specific %{linkStart}permissions to a base role.%{linkEnd}',
    ),
    newRoleText: s__('MemberRole|New role'),
    fetchRolesError: s__('MemberRole|Failed to fetch roles.'),
    roleDeletedText: s__('MemberRole|Role successfully deleted.'),
  },
  components: {
    GlLoadingIcon,
    GlSprintf,
    GlLink,
    GlButton,
    GlIcon,
    GlAlert,
    CustomRolesEmptyState,
    RolesTable,
    DeleteRoleModal,
  },
  inject: ['documentationPath', 'groupFullPath', 'newRolePath'],
  data() {
    return {
      customRoles: null,
      isDeletingRole: false,
      roleToDelete: null,
      error: null,
    };
  },
  apollo: {
    customRoles: {
      query() {
        return this.groupFullPath ? groupMemberRolesQuery : instanceMemberRolesQuery;
      },
      variables() {
        return this.groupFullPath ? { fullPath: this.groupFullPath } : {};
      },
      update(data) {
        const nodes = this.groupFullPath
          ? data?.namespace?.memberRoles?.nodes
          : data?.memberRoles?.nodes;

        return nodes || [];
      },
      error() {
        this.error = this.$options.i18n.fetchRolesError;
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.customRoles.loading;
    },
    isLoadingInitial() {
      // Whether the custom roles are loading for the first time rather than a refetch.
      return this.isLoading && !this.customRoles;
    },
    customRolesCount() {
      return n__('%d Custom role', '%d Custom roles', this.customRoles.length);
    },
  },
  methods: {
    processRoleDeletion() {
      this.roleToDelete = null;
      this.$toast.show(this.$options.i18n.roleDeletedText);
      this.$apollo.queries.customRoles.refetch();
    },
  },
};
</script>

<template>
  <gl-loading-icon v-if="isLoadingInitial" size="md" class="gl-mt-5" />

  <gl-alert v-else-if="error" variant="danger" class="gl-mt-5" :dismissible="false">
    {{ error }}
  </gl-alert>

  <custom-roles-empty-state v-else-if="!customRoles.length" />

  <section v-else>
    <header>
      <div class="page-title gl-mb-2 gl-flex gl-flex-wrap gl-items-start gl-gap-2">
        <h1 class="gl-m-0 gl-mr-auto gl-whitespace-nowrap gl-text-size-h-display">
          {{ $options.i18n.title }}
        </h1>
        <gl-button :href="newRolePath" variant="confirm">
          {{ $options.i18n.newRoleText }}
        </gl-button>
      </div>

      <p class="gl-mb-7">
        <gl-sprintf :message="$options.i18n.description">
          <template #link="{ content }">
            <gl-link :href="documentationPath" target="_blank">
              {{ content }}
            </gl-link>
          </template>
        </gl-sprintf>
      </p>
    </header>

    <div class="gl-mb-4 gl-font-bold" data-testid="custom-roles-count">
      <gl-icon name="shield" class="gl-mr-2" />
      <span>{{ customRolesCount }}</span>
    </div>

    <roles-table :roles="customRoles" :busy="isLoading" @delete-role="roleToDelete = $event" />
    <delete-role-modal
      :role="roleToDelete"
      @deleted="processRoleDeletion"
      @close="roleToDelete = null"
    />
  </section>
</template>
