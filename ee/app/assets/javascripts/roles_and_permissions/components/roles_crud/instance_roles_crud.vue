<script>
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import glLicensedFeaturesMixin from '~/vue_shared/mixins/gl_licensed_features_mixin';
import instanceRolesQuery from '../../graphql/instance_roles.query.graphql';
import RolesCrud from './roles_crud.vue';
import { showRolesFetchError, createNewCustomRoleOption, createNewAdminRoleOption } from './utils';

export default {
  components: { RolesCrud },
  mixins: [glFeatureFlagsMixin(), glLicensedFeaturesMixin()],
  inject: ['newRolePath'],
  data() {
    return {
      roles: {},
    };
  },
  computed: {
    isCustomAdminRolesAvailable() {
      return this.glLicensedFeatures.customRoles && this.glFeatures.customAdminRoles;
    },
    newRoleOptions() {
      if (!this.newRolePath) return [];

      const items = [createNewCustomRoleOption(this.newRolePath)];
      // Add the ability to create admin roles if the feature is enabled.
      if (this.isCustomAdminRolesAvailable) {
        items.push(createNewAdminRoleOption(this.newRolePath));
      }

      return items;
    },
  },
  apollo: {
    roles: {
      query: instanceRolesQuery,
      variables() {
        return {
          includeCustomRoles: this.glLicensedFeatures.customRoles,
          includeAdminRoles: this.isCustomAdminRolesAvailable,
        };
      },
      update: (data) => data,
      error: showRolesFetchError,
    },
  },
};
</script>

<template>
  <roles-crud
    :roles="roles"
    :loading="$apollo.queries.roles.loading"
    :new-role-options="newRoleOptions"
    @deleted="() => $apollo.queries.roles.refetch()"
  />
</template>
