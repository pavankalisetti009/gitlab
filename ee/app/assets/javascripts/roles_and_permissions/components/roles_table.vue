<script>
import { GlTable, GlLoadingIcon } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { s__ } from '~/locale';
import RoleActions from './role_actions.vue';

export const TABLE_FIELDS = [
  { key: 'id', label: s__('MemberRole|ID') },
  { key: 'name', label: s__('MemberRole|Name') },
  { key: 'description', label: s__('MemberRole|Description') },
  { key: 'baseRole', label: s__('MemberRole|Base role') },
  {
    key: 'permissions',
    label: s__('MemberRole|Custom permissions'),
    tdClass: 'gl-whitespace-nowrap',
  },
  {
    key: 'membersCount',
    label: s__('MemberRole|Member count'),
    thClass: 'gl-w-12 gl-whitespace-nowrap',
    tdClass: 'gl-text-right',
  },
  {
    key: 'actions',
    label: s__('MemberRole|Actions'),
    thClass: 'gl-w-12',
    tdClass: 'gl-text-right !gl-p-3',
  },
];

export default {
  components: { GlTable, GlLoadingIcon, RoleActions },
  props: {
    roles: {
      type: Array,
      required: true,
    },
    busy: {
      type: Boolean,
      required: true,
    },
  },
  TABLE_FIELDS,
  getIdFromGraphQLId,
};
</script>

<template>
  <gl-table :fields="$options.TABLE_FIELDS" :items="roles" :busy="busy" stacked="md">
    <template #table-busy>
      <gl-loading-icon size="md" />
    </template>

    <template #cell(id)="{ item: { id } }">
      {{ $options.getIdFromGraphQLId(id) }}
    </template>

    <template #cell(description)="{ item: { description } }">
      <template v-if="description">{{ description }}</template>
      <span v-else class="gl-text-subtle">{{ s__('MemberRole|No description') }}</span>
    </template>

    <template #cell(baseRole)="{ item: { baseAccessLevel } }">
      {{ baseAccessLevel.humanAccess }}
    </template>

    <template #cell(permissions)="{ item: { enabledPermissions } }">
      <div v-for="{ value, name } in enabledPermissions.nodes" :key="value" class="gl-mb-2">
        {{ name }}
      </div>
    </template>

    <template #cell(actions)="{ item }">
      <role-actions :role="item" @delete="$emit('delete-role', item)" />
    </template>
  </gl-table>
</template>
