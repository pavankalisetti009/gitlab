<script>
import { GlDisclosureDropdownGroup, GlDisclosureDropdownItem, GlIcon } from '@gitlab/ui';
import { USER_MENU_TRACKING_DEFAULTS } from '~/super_sidebar/constants';

export default {
  name: 'UserMenuUpgradeSubscription',
  components: {
    GlDisclosureDropdownGroup,
    GlDisclosureDropdownItem,
    GlIcon,
  },
  props: {
    upgradeLink: {
      type: Object,
      required: true,
    },
  },
  computed: {
    upgradeSubscriptionItem() {
      return {
        text: this.upgradeLink.text,
        href: this.upgradeLink.url,
        extraAttrs: {
          ...USER_MENU_TRACKING_DEFAULTS,
          'data-track-label': 'upgrade_subscription',
        },
      };
    },
  },
};
</script>

<template>
  <gl-disclosure-dropdown-group bordered>
    <gl-disclosure-dropdown-item
      :item="upgradeSubscriptionItem"
      data-testid="upgrade-subscription-item"
    >
      <template #list-item>
        <span class="hotspot-pulse gl-flex gl-items-center gl-gap-2">
          <gl-icon name="license" variant="subtle" class="gl-mr-2" />
          {{ upgradeSubscriptionItem.text }}
        </span>
      </template>
    </gl-disclosure-dropdown-item>
  </gl-disclosure-dropdown-group>
</template>
