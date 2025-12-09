<script>
import { GlFormGroup, GlFormSelect } from '@gitlab/ui';
import { pick } from 'lodash';
import { s__ } from '~/locale';
import {
  ACCESS_LEVEL_DEVELOPER_INTEGER,
  ACCESS_LEVEL_MAINTAINER_INTEGER,
  ACCESS_LEVEL_ADMIN_INTEGER,
  ACCESS_LEVEL_OWNER_INTEGER,
  ACCESS_LEVEL_ADMIN,
  ACCESS_LEVEL_LABELS,
} from '~/access_level/constants';

export default {
  name: 'AiRolePermissions',
  components: {
    GlFormGroup,
    GlFormSelect,
  },
  inject: {
    isAdminInstanceDuoHome: { default: false },
  },
  props: {
    enableOnProjectsMinimumRole: {
      type: Number,
      required: false,
      default: ACCESS_LEVEL_MAINTAINER_INTEGER,
    },
    executeMinimumRole: {
      type: Number,
      required: false,
      default: ACCESS_LEVEL_DEVELOPER_INTEGER,
    },
    manageMinimumRole: {
      type: Number,
      required: false,
      default: ACCESS_LEVEL_MAINTAINER_INTEGER,
    },
  },
  emits: ['enable-role-change', 'execute-role-change', 'manage-role-change'],
  data() {
    return {
      selectedEnableRole: this.enableOnProjectsMinimumRole,
      selectedManageRole: this.manageMinimumRole,
      selectedExecuteRole: this.executeMinimumRole,
    };
  },
  computed: {
    enableOnProjectsRoleOptions() {
      const roles = [ACCESS_LEVEL_MAINTAINER_INTEGER, ACCESS_LEVEL_OWNER_INTEGER];
      if (this.isAdminInstanceDuoHome) {
        roles.push(ACCESS_LEVEL_ADMIN_INTEGER);
      }
      return this.generateSelectOptions(roles);
    },
    manageRoleOptions() {
      const roles = [ACCESS_LEVEL_MAINTAINER_INTEGER, ACCESS_LEVEL_OWNER_INTEGER];
      if (this.isAdminInstanceDuoHome) {
        roles.push(ACCESS_LEVEL_ADMIN_INTEGER);
      }
      return this.generateSelectOptions(roles);
    },
    executeRoleOptions() {
      const roles = [
        ACCESS_LEVEL_DEVELOPER_INTEGER,
        ACCESS_LEVEL_MAINTAINER_INTEGER,
        ACCESS_LEVEL_OWNER_INTEGER,
      ];
      if (this.isAdminInstanceDuoHome) {
        roles.push(ACCESS_LEVEL_ADMIN_INTEGER);
      }
      return this.generateSelectOptions(roles);
    },
  },
  methods: {
    generateSelectOptions(roles) {
      return Object.entries(pick(this.$options.ALL_ACCESS_LEVELS_LABELS, roles)).map(
        ([value, label]) => ({
          text: label,
          value: parseInt(value, 10),
        }),
      );
    },
    onEnableRoleSelect(roleValue) {
      this.selectedManageRole = roleValue;
      this.$emit('enable-role-change', roleValue);
    },
    onExecuteRoleSelect(roleValue) {
      this.selectedExecuteRole = roleValue;
      this.$emit('execute-role-change', roleValue);
    },
    onManageRoleSelect(roleValue) {
      this.selectedManageRole = roleValue;
      this.$emit('manage-role-change', roleValue);
    },
  },
  i18n: {
    enablePermissionDescription: s__(
      'AiPowered|Minimum role required to enable agents and flows on projects.',
    ),
    enablePermissionLabel: s__('AiPowered|Enable'),
    managePermissionDescription: s__(
      'AiPowered|Minimum role required to create, duplicate, edit, delete, and show agents and flows.',
    ),
    managePermissionLabel: s__('AiPowered|Manage'),
    executePermissionDescription: s__(
      'AiPowered|Minimum role required to execute agents and flows.',
    ),
    executePermissionLabel: s__('AiPowered|Execute'),
    sectionDescription: s__(
      'AiPowered|Define the minimum role level to perform each of the following actions',
    ),
    sectionTitle: s__('AiPowered|Agent & Flow Permissions'),
  },
  ALL_ACCESS_LEVELS_LABELS: {
    ...ACCESS_LEVEL_LABELS,
    [ACCESS_LEVEL_ADMIN_INTEGER]: ACCESS_LEVEL_ADMIN,
  },
};
</script>
<template>
  <div>
    <gl-form-group :label="$options.i18n.sectionTitle" class="gl-my-4">
      <template #label-description>
        <p class="gl-mb-3 gl-text-subtle">{{ $options.i18n.sectionDescription }}</p>
      </template>

      <div>
        <gl-form-group
          :label="$options.i18n.enablePermissionLabel"
          :description="$options.i18n.enablePermissionDescription"
          label-for="enable-role-selector"
          class="gl-mb-5"
        >
          <gl-form-select
            id="enable-role-selector"
            v-model="selectedEnableRole"
            :options="enableOnProjectsRoleOptions"
            data-testid="enable-role-selector"
            @change="onEnableRoleSelect"
          />
        </gl-form-group>

        <gl-form-group
          :label="$options.i18n.managePermissionLabel"
          :description="$options.i18n.managePermissionDescription"
          label-for="manage-role-selector"
          class="gl-mb-5"
        >
          <gl-form-select
            id="manage-role-selector"
            v-model="selectedManageRole"
            :options="manageRoleOptions"
            data-testid="manage-role-selector"
            @change="onManageRoleSelect"
          />
        </gl-form-group>

        <gl-form-group
          :label="$options.i18n.executePermissionLabel"
          :description="$options.i18n.executePermissionDescription"
          label-for="execute-role-selector"
        >
          <gl-form-select
            id="execute-role-selector"
            v-model="selectedExecuteRole"
            :options="executeRoleOptions"
            data-testid="execute-role-selector"
            @change="onExecuteRoleSelect"
          />
        </gl-form-group>
      </div>
    </gl-form-group>
  </div>
</template>
