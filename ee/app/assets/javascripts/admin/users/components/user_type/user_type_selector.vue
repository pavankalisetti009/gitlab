<script>
import UserTypeSelectorCe, {
  USER_TYPE_REGULAR,
  USER_TYPE_ADMIN,
} from '~/admin/users/components/user_type/user_type_selector.vue';
import RegularAccessSummary from '~/admin/users/components/user_type/regular_access_summary.vue';
import AdminAccessSummary from '~/admin/users/components/user_type/admin_access_summary.vue';
import { s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import AuditorAccessSummary from './auditor_access_summary.vue';
import AdminRoleDropdown from './admin_role_dropdown.vue';

export const USER_TYPE_AUDITOR = {
  value: 'auditor',
  text: s__('AdminUsers|Auditor'),
  description: s__(
    'AdminUsers|Read-only access to all groups and projects. No access to the Admin area by default.',
  ),
};

export default {
  components: {
    UserTypeSelectorCe,
    AdminRoleDropdown,
    RegularAccessSummary,
    AuditorAccessSummary,
    AdminAccessSummary,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    userType: {
      type: String,
      required: true,
    },
    isCurrentUser: {
      type: Boolean,
      required: true,
    },
    licenseAllowsAuditorUser: {
      type: Boolean,
      required: true,
    },
    adminRoleId: {
      type: Number,
      required: false,
      default: undefined,
    },
  },
  data() {
    return {
      currentUserType: this.userType,
    };
  },
  computed: {
    isRegularSelected() {
      return this.currentUserType === USER_TYPE_REGULAR.value;
    },
    isAuditorSelected() {
      return this.currentUserType === USER_TYPE_AUDITOR.value;
    },
    isAdminSelected() {
      return this.currentUserType === USER_TYPE_ADMIN.value;
    },
    userTypes() {
      return this.licenseAllowsAuditorUser
        ? [USER_TYPE_REGULAR, USER_TYPE_AUDITOR, USER_TYPE_ADMIN]
        : [USER_TYPE_REGULAR, USER_TYPE_ADMIN];
    },
    shouldShowAdminRoleDropdown() {
      return (
        this.glFeatures.customRoles &&
        this.glFeatures.customAdminRoles &&
        (this.isRegularSelected || this.isAuditorSelected)
      );
    },
  },
};
</script>

<template>
  <user-type-selector-ce
    :user-type="userType"
    :is-current-user="isCurrentUser"
    :user-types="userTypes"
    @access-change="currentUserType = $event"
  >
    <template v-if="shouldShowAdminRoleDropdown" #description>
      <p class="gl-mb-0 gl-text-subtle">
        {{ s__('AdminUsers|Review and set Admin area access with a custom admin role.') }}
      </p>
    </template>

    <regular-access-summary v-if="isRegularSelected">
      <admin-role-dropdown v-if="shouldShowAdminRoleDropdown" :role-id="adminRoleId" />
    </regular-access-summary>

    <auditor-access-summary v-else-if="isAuditorSelected">
      <admin-role-dropdown v-if="shouldShowAdminRoleDropdown" :role-id="adminRoleId" />
    </auditor-access-summary>

    <admin-access-summary v-else-if="isAdminSelected" />
  </user-type-selector-ce>
</template>
