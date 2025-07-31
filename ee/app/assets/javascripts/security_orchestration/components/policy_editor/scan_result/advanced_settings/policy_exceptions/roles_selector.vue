<script>
import { GlFormGroup } from '@gitlab/ui';
import { s__ } from '~/locale';
import RoleSelect from 'ee/security_orchestration/components/shared/role_select.vue';

export default {
  i18n: {
    roleSelectorLabel: s__('ScanResultPolicy|Select role exceptions'),
    roleSelectorDescription: s__('ScanResultPolicy|Choose which roles can bypass this policy'),
  },
  name: 'RolesSelector',
  components: {
    GlFormGroup,
    RoleSelect,
  },
  props: {
    selectedRoles: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  methods: {
    isCustomRole(id) {
      return !Number.isNaN(parseInt(id, 10));
    },
    selectRoles({ role_approvers: roles = [] }) {
      const payload = roles.reduce(
        (acc, roleId) => {
          const targetArray = this.isCustomRole(roleId) ? 'custom_roles' : 'roles';
          acc[targetArray].push(roleId);
          return acc;
        },
        { roles: [], custom_roles: [] },
      );

      this.$emit('set-roles', payload);
    },
  },
};
</script>

<template>
  <div class="gl-w-full gl-px-3 gl-py-4">
    <gl-form-group
      id="roles-list"
      class="gl-w-full"
      label-for="roles-list"
      :label="$options.i18n.roleSelectorLabel"
      :description="$options.i18n.roleSelectorDescription"
    >
      <role-select
        class="gl-w-full"
        :custom-dropdown-classes="['gl-flex-1']"
        :selected="selectedRoles"
        data-testid="roles-items"
        @error="$emit('error')"
        @select-items="selectRoles"
      />
    </gl-form-group>
  </div>
</template>
