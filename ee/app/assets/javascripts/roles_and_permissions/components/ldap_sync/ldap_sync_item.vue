<script>
import { GlButton, GlIcon, GlTooltipDirective } from '@gitlab/ui';

export default {
  components: { GlButton, GlIcon },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    roleLink: {
      type: Object,
      required: true,
    },
  },
  computed: {
    isUnknownLdapServer() {
      return !this.roleLink.provider.label;
    },
  },
};
</script>

<template>
  <li class="gl-flex-row-reverse gl-items-center sm:!gl-flex">
    <gl-button
      variant="danger"
      category="secondary"
      icon="remove"
      :aria-label="s__('MemberRole|Remove sync')"
      class="gl-float-right gl-ml-3 gl-mt-2"
      @click="$emit('delete')"
    />

    <dl class="gl-mb-0 gl-flex-1 gl-grid-cols-[auto_1fr] gl-gap-x-5 sm:gl-grid">
      <dt class="gl-mb-1">{{ s__('MemberRole|Server:') }}</dt>
      <dd class="gl-mb-4 gl-text-subtle" :class="{ 'gl-text-warning': isUnknownLdapServer }">
        {{ roleLink.provider.label || roleLink.provider.id }}
        <gl-icon
          v-if="isUnknownLdapServer"
          v-gl-tooltip.d0="
            s__('MemberRole|Unknown LDAP server. Please check your server settings.')
          "
          name="warning-solid"
          variant="warning"
          class="gl-ml-1"
        />
      </dd>

      <template v-if="roleLink.filter">
        <dt class="gl-mb-1">{{ s__('MemberRole|User filter:') }}</dt>
        <dd class="gl-text-subtle">{{ roleLink.filter }}</dd>
      </template>

      <template v-else-if="roleLink.cn">
        <dt class="gl-mb-1">{{ s__('MemberRole|Group cn:') }}</dt>
        <dd class="gl-text-subtle">{{ roleLink.cn }}</dd>
      </template>

      <dt class="gl-mb-1">{{ s__('MemberRole|Custom admin role:') }}</dt>
      <dd class="gl-mb-0 gl-text-subtle">
        {{ roleLink.adminMemberRole.name }}
      </dd>
    </dl>
  </li>
</template>
