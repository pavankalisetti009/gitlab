<script>
import { GlAvatarLabeled, GlButton, GlTab, GlTableLite } from '@gitlab/ui';
import { upperFirst } from 'lodash';
import { __ } from '~/locale';
import { ACCESS_LEVELS_INTEGER_TO_STRING } from '~/access_level/constants';
import {
  PERMISSION_CATEGORY_GROUP,
  PERMISSION_CATEGORY_ROLE,
  PERMISSION_CATEGORY_USER,
} from '../constants';

export default {
  name: 'SecretsManagerPermissionsTable',
  components: {
    GlAvatarLabeled,
    GlButton,
    GlTab,
    GlTableLite,
  },
  props: {
    canDelete: {
      type: Boolean,
      required: true,
    },
    items: {
      type: Array,
      required: true,
    },
    permissionCategory: {
      type: String,
      required: true,
    },
  },
  data() {
    return {};
  },
  computed: {
    isCategoryGroup() {
      return this.permissionCategory === PERMISSION_CATEGORY_GROUP;
    },
    isCategoryRole() {
      return this.permissionCategory === PERMISSION_CATEGORY_ROLE;
    },
    isCategoryUser() {
      return this.permissionCategory === PERMISSION_CATEGORY_USER;
    },
    tableFields() {
      return [
        ...(this.isCategoryUser
          ? [
              {
                key: 'user',
                label: __('User'),
              },
              {
                key: 'role',
                label: __('Role'),
              },
            ]
          : []),
        ...(this.isCategoryGroup
          ? [
              {
                key: 'group',
                label: __('Group'),
                thClass: !this.canDelete ? 'gl-w-1/3' : 'gl-w-1/4',
              },
            ]
          : []),
        ...(this.isCategoryRole
          ? [
              {
                key: 'role',
                label: __('Role'),
                thClass: !this.canDelete ? 'gl-w-1/3' : 'gl-w-1/4',
              },
            ]
          : []),
        {
          key: 'scope',
          label: __('Scope'),
          thClass: !this.canDelete ? 'gl-w-1/3' : 'gl-w-1/4',
        },
        // TODO: Add expiration column once available
        // See https://gitlab.com/gitlab-org/gitlab/-/issues/560580
        {
          key: 'access-granted',
          label: __('Access granted'),
        },
        ...(this.canDelete
          ? [
              {
                key: 'actions',
                label: __('Actions'),
              },
            ]
          : []),
      ];
    },
    tableTitle() {
      if (this.permissionCategory === PERMISSION_CATEGORY_USER) {
        return __('Users');
      }

      if (this.permissionCategory === PERMISSION_CATEGORY_GROUP) {
        return __('Group');
      }

      return __('Roles');
    },
  },
  methods: {
    formatPermissions(permissions) {
      const scopes = JSON.parse(permissions).map((p) => upperFirst(p));
      return scopes.join(', ');
    },
    formatRoleName(id) {
      const role = ACCESS_LEVELS_INTEGER_TO_STRING[id] || '';
      return upperFirst(role.toLowerCase());
    },
  },
};
</script>

<template>
  <gl-tab :title="tableTitle">
    <gl-table-lite :items="items" :fields="tableFields">
      <template
        v-if="isCategoryUser"
        #cell(user)="{
          item: {
            principal: { user },
          },
        }"
      >
        <gl-avatar-labeled
          :size="32"
          :src="user.avatarUrl"
          :label="user.username"
          :label-link="user.webUrl"
          :sub-label="user.name"
        />
      </template>
      <template
        v-if="isCategoryGroup"
        #cell(group)="{
          item: {
            principal: { group },
          },
        }"
      >
        <gl-avatar-labeled
          :src="group.avatarUrl"
          :size="32"
          :entity-name="group.name"
          :label="group.name"
          :label-link="group.webUrl"
        />
      </template>
      <template v-if="!isCategoryGroup" #cell(role)="{ item: { principal } }">
        <span v-if="isCategoryUser">{{ formatRoleName(principal.userRoleId) }}</span>
        <span v-if="isCategoryRole">{{ formatRoleName(principal.id) }}</span>
      </template>
      <template #cell(scope)="{ item: { permissions } }">
        {{ formatPermissions(permissions) }}
      </template>
      <template #cell(access-granted)="{ item: { grantedBy } }">
        <gl-avatar-labeled
          v-if="Boolean(grantedBy)"
          :size="32"
          :src="grantedBy.avatarUrl"
          :label="grantedBy.username"
          :label-link="grantedBy.webUrl"
          :sub-label="grantedBy.name"
        />
        <span v-else>{{ __('N/A') }}</span>
      </template>
      <template #cell(actions)="{ item: { principal } }">
        <gl-button
          icon="remove"
          :title="__('Delete')"
          :aria-label="__('Delete')"
          @click="$emit('delete-permission', principal)"
        />
      </template>
    </gl-table-lite>
  </gl-tab>
</template>
