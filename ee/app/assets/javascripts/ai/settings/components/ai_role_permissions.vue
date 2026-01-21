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
  ACCESS_LEVEL_GUEST_INTEGER,
  ACCESS_LEVEL_REPORTER_INTEGER,
  ACCESS_LEVEL_PLANNER_INTEGER,
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
    initialMinimumAccessLevelExecuteAsync: {
      type: Number,
      required: true,
    },
    initialMinimumAccessLevelExecuteSync: {
      type: Number,
      required: true,
    },
  },
  emits: ['minimum-access-level-execute-async-change', 'minimum-access-level-execute-sync-change'],
  data() {
    return {
      minimumAccessLevelExecuteAsync: this.initialMinimumAccessLevelExecuteAsync,
      minimumAccessLevelExecuteSync: this.initialMinimumAccessLevelExecuteSync,
    };
  },
  computed: {
    minimumAccessLevelExecuteAsyncOptions() {
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
    minimumAccessLevelExecuteSyncOptions() {
      const roles = [
        ACCESS_LEVEL_GUEST_INTEGER,
        ACCESS_LEVEL_REPORTER_INTEGER,
        ACCESS_LEVEL_PLANNER_INTEGER,
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
    changeMinimumAccessLevelExecuteAsync(role) {
      this.minimumAccessLevelExecuteAsync = role;
      this.$emit('minimum-access-level-execute-async-change', role);
    },
    changeMinimumAccessLevelExecuteSync(role) {
      this.minimumAccessLevelExecuteSync = role;
      this.$emit('minimum-access-level-execute-sync-change', role);
    },
  },
  i18n: {
    minimumAccessLevelExecuteAsyncLabel: s__(
      'AiPowered|Execute Duo Agent Platform with CI/CD pipelines',
    ),
    minimumAccessLevelExecuteAsyncDescription: s__(
      'AiPowered|Control who can use AI features that run using CI/CD pipelines.',
    ),
    minimumAccessLevelExecuteSyncLabel: s__('AiPowered|Execute Duo Agent Platform'),
    minimumAccessLevelExecuteSyncDescription: s__(
      'AiPowered|Control who can use AI features that run without using CI/CD pipelines.',
    ),
    sectionDescription: s__('AiPowered|Define the minimum role for the following actions'),
    sectionTitle: s__('AiPowered|Duo Agent Platform Permissions'),
  },
  ALL_ACCESS_LEVELS_LABELS: {
    ...ACCESS_LEVEL_LABELS,
    [ACCESS_LEVEL_ADMIN_INTEGER]: ACCESS_LEVEL_ADMIN,
  },
};
</script>
<template>
  <div>
    <gl-form-group :label="$options.i18n.sectionTitle" class="gl-mb-0">
      <template #label-description>
        <p class="gl-mb-3 gl-text-subtle">{{ $options.i18n.sectionDescription }}</p>
      </template>

      <div>
        <gl-form-group
          :label="$options.i18n.minimumAccessLevelExecuteSyncLabel"
          :description="$options.i18n.minimumAccessLevelExecuteSyncDescription"
          label-for="minimum-access-level-execute-sync-selector"
        >
          <gl-form-select
            id="minimum-access-level-execute-sync-selector"
            v-model="minimumAccessLevelExecuteSync"
            :options="minimumAccessLevelExecuteSyncOptions"
            data-testid="minimum-access-level-execute-sync-selector"
            class="gl-max-w-26"
            @change="changeMinimumAccessLevelExecuteSync"
          />
        </gl-form-group>

        <gl-form-group
          :label="$options.i18n.minimumAccessLevelExecuteAsyncLabel"
          :description="$options.i18n.minimumAccessLevelExecuteAsyncDescription"
          label-for="minimum-access-level-execute-async-selector"
        >
          <gl-form-select
            id="minimum-access-level-execute-async-selector"
            v-model="minimumAccessLevelExecuteAsync"
            :options="minimumAccessLevelExecuteAsyncOptions"
            data-testid="minimum-access-level-execute-async-selector"
            class="gl-max-w-26"
            @change="changeMinimumAccessLevelExecuteAsync"
          />
        </gl-form-group>
      </div>
    </gl-form-group>
  </div>
</template>
