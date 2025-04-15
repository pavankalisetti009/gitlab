<script>
import { GlTabs, GlTab, GlSprintf, GlLink } from '@gitlab/ui';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { helpPagePath } from '~/helpers/help_page_helper';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import RolesCrud from './roles_table/roles_crud.vue';

export default {
  components: { PageHeading, GlTabs, GlTab, RolesCrud, GlSprintf, GlLink },
  mixins: [glFeatureFlagsMixin()],
  props: {
    isLdapEnabled: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    showTabs() {
      return this.isLdapEnabled && this.glFeatures.customAdminRoles;
    },
  },
  userPermissionsDocPath: helpPagePath('user/permissions'),
};
</script>

<template>
  <div>
    <page-heading :heading="s__('MemberRole|Roles and permissions')">
      <template #description>
        <gl-sprintf
          :message="
            s__(
              'MemberRole|Manage which actions users can take with %{linkStart}roles and permissions%{linkEnd}.',
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="$options.userPermissionsDocPath" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </template>
    </page-heading>

    <gl-tabs v-if="showTabs" sync-active-tab-with-query-params>
      <gl-tab :title="__('Roles')" query-param-value="roles">
        <roles-crud class="gl-mt-5" />
      </gl-tab>
      <gl-tab :title="__('LDAP Synchronization')" query-param-value="ldap" />
    </gl-tabs>

    <roles-crud v-else />
  </div>
</template>
