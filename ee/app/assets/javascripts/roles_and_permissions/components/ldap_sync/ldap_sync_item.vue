<script>
import { GlButton } from '@gitlab/ui';

export default {
  components: { GlButton },
  props: {
    roleLink: {
      type: Object,
      required: true,
    },
  },
};
</script>

<template>
  <li class="!gl-py-5">
    <div class="gl-flex gl-flex-wrap gl-items-center gl-justify-end gl-gap-5">
      <dl class="gl-mb-0 gl-grid gl-flex-1 gl-grid-cols-[auto_1fr] gl-gap-x-5 gl-whitespace-nowrap">
        <dt>{{ s__('MemberRole|Server:') }}</dt>
        <dd class="gl-text-subtle">{{ roleLink.provider.label }}</dd>

        <template v-if="roleLink.filter">
          <dt>{{ s__('MemberRole|User filter:') }}</dt>
          <dd class="gl-text-subtle">{{ roleLink.filter }}</dd>
        </template>

        <template v-else-if="roleLink.cn">
          <dt>{{ s__('MemberRole|Group cn:') }}</dt>
          <dd class="gl-text-subtle">{{ roleLink.cn }}</dd>
        </template>

        <dt>{{ s__('MemberRole|Custom admin role:') }}</dt>
        <dd class="gl-mb-0 gl-text-subtle">{{ roleLink.adminMemberRole.name }}</dd>
      </dl>

      <gl-button
        variant="danger"
        category="secondary"
        icon="remove"
        :aria-label="s__('MemberRole|Remove sync')"
        @click="$emit('delete')"
      />
    </div>
  </li>
</template>
