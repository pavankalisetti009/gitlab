<script>
import { GlDisclosureDropdown, GlDisclosureDropdownItem } from '@gitlab/ui';

export default {
  name: 'SecretActionsCell',
  components: {
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
  },
  props: {
    detailsRoute: {
      type: Object,
      required: true,
    },
    secretName: {
      type: String,
      required: true,
    },
  },
  methods: {
    deleteSecret() {
      this.$emit('delete-secret', this.secretName);
    },
  },
};
</script>
<template>
  <gl-disclosure-dropdown
    icon="ellipsis_v"
    :toggle-text="__('Actions')"
    text-sr-only
    category="tertiary"
    no-caret
  >
    <gl-disclosure-dropdown-item>
      <template #list-item>
        <router-link
          data-testid="secret-details-link"
          :to="detailsRoute"
          class="gl-block gl-text-default hover:gl-text-default hover:gl-no-underline"
        >
          {{ __('Edit') }}
        </router-link>
      </template>
    </gl-disclosure-dropdown-item>
    <gl-disclosure-dropdown-item @action="deleteSecret">
      <template #list-item>
        <span class="gl-text-danger">{{ __('Delete') }}</span>
      </template>
    </gl-disclosure-dropdown-item>
  </gl-disclosure-dropdown>
</template>
