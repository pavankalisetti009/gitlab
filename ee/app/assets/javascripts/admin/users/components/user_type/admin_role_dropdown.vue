<script>
import { GlCollapsibleListbox, GlAlert, GlIcon } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { visitUrl } from '~/lib/utils/url_utility';
import { __, s__ } from '~/locale';
import adminRolesQuery from '../../graphql/admin_roles.query.graphql';

const NO_ACCESS_VALUE = -1;
const NO_ACCESS_TEXT = __('No access');

export default {
  components: { GlCollapsibleListbox, GlAlert, GlIcon },
  inject: ['manageRolesPath'],
  props: {
    roleId: {
      type: Number,
      required: false,
      default: NO_ACCESS_VALUE,
    },
  },
  data() {
    return {
      adminRoles: [],
      currentRoleId: this.roleId,
    };
  },
  apollo: {
    adminRoles: {
      query: adminRolesQuery,
      update(data) {
        return data.adminMemberRoles.nodes.map((role) => ({
          ...role,
          value: getIdFromGraphQLId(role.id),
          text: role.name,
        }));
      },
      error() {
        this.adminRoles = null;
      },
    },
  },
  computed: {
    isLoadingAdminRoles() {
      return this.$apollo.queries.adminRoles.loading;
    },
    dropdownItems() {
      return [
        {
          text: NO_ACCESS_TEXT,
          options: [{ text: NO_ACCESS_TEXT, value: NO_ACCESS_VALUE }],
          textSrOnly: true,
        },
        {
          text: s__('AdminUsers|Custom admin roles'),
          options: this.adminRoles,
        },
      ];
    },
    rolePermissions() {
      const role = this.adminRoles.find(({ value }) => value === this.currentRoleId);
      return role?.enabledPermissions.nodes;
    },
    roleIdValue() {
      return this.currentRoleId === NO_ACCESS_VALUE ? '' : this.currentRoleId;
    },
  },
  methods: {
    goToManageRolesPage() {
      visitUrl(this.manageRolesPath);
    },
  },
  NO_ACCESS_VALUE,
};
</script>

<template>
  <gl-alert v-if="!adminRoles" :dismissible="false" variant="danger" class="gl-inline-block">
    {{ s__('AdminUsers|Could not load custom admin roles.') }}
  </gl-alert>

  <div v-else>
    <gl-collapsible-listbox
      v-model="currentRoleId"
      class="gl-w-28"
      block
      positioning-strategy="fixed"
      :loading="isLoadingAdminRoles"
      :toggle-text="isLoadingAdminRoles ? __('Loading...') : ''"
      :items="dropdownItems"
      :header-text="s__('AdminUsers|Change access')"
      :reset-button-label="s__('MemberRole|Manage roles')"
      @reset="goToManageRolesPage"
    >
      <template #list-item="{ item }">
        <div
          class="gl-line-clamp-2"
          :class="{ 'gl-font-bold': item.value !== $options.NO_ACCESS_VALUE }"
        >
          {{ item.text }}
        </div>
        <div v-if="item.description" class="gl-mt-2 gl-line-clamp-2 gl-text-sm gl-text-subtle">
          {{ item.description }}
        </div>
      </template>

      <template v-if="!adminRoles.length" #footer>
        <div class="gl-px-4 gl-pb-3 gl-text-sm gl-text-subtle">
          {{ s__('AdminUsers|Create admin role to populate this list.') }}
        </div>
      </template>
    </gl-collapsible-listbox>

    <input name="user[admin_role_id]" :value="roleIdValue" type="hidden" />

    <ul
      v-if="rolePermissions"
      class="gl-mb-0 gl-mt-3 gl-list-none gl-pl-0"
      data-testid="permissions"
    >
      <li v-for="{ name } in rolePermissions" :key="name">
        <gl-icon name="check" variant="success" />
        <span class="gl-text-subtle">{{ name }}</span>
      </li>
    </ul>
  </div>
</template>
