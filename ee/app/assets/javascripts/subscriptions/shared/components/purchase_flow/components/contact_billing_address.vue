<script>
import { s__ } from '~/locale';

export default {
  props: {
    isSoldToContact: {
      type: Boolean,
      required: true,
    },
    contact: {
      type: Object,
      required: true,
    },
  },
  computed: {
    addressTitle() {
      return this.isSoldToContact
        ? this.$options.i18n.subscriptionContactTitle
        : this.$options.i18n.billingContactTitle;
    },
    contactName() {
      if (!this.contact.fullName) {
        return `${this.contact.firstName} ${this.contact.lastName}`;
      }

      return this.contact.fullName;
    },
    // Address fields not required by CDot backend: https://gitlab.com/gitlab-org/customers-gitlab-com/-/blob/420e698565230dd1f9361677aa89df3d5f1c7394/app/models/billing_account_contact.rb#L13-13
    hasAddress1() {
      return Boolean(this.contact.address1);
    },
    hasAddress2() {
      return Boolean(this.contact.address2);
    },
  },
  i18n: {
    subscriptionContactTitle: s__('Checkout|Subscription contact'),
    billingContactTitle: s__('Checkout|Billing contact'),
  },
};
</script>
<template>
  <div>
    <h6>{{ addressTitle }}</h6>

    <div data-testid="billing-contact-full-name">{{ contactName }}</div>
    <div data-testid="billing-contact-work-email">{{ contact.workEmail }}</div>
    <div v-if="hasAddress1" data-testid="billing-contact-address1">{{ contact.address1 }}</div>
    <div v-if="hasAddress2" data-testid="billing-contact-address2">{{ contact.address2 }}</div>
    <div data-testid="billing-contact-city-state">{{ contact.city }}, {{ contact.state }}</div>
    <div data-testid="billing-contact-postal-code">{{ contact.postalCode }}</div>
    <div data-testid="billing-contact-country">{{ contact.country }}</div>
  </div>
</template>
