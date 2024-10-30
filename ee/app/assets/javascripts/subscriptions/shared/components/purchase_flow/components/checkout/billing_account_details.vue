<script>
import CompanyInformation from 'ee/subscriptions/shared/components/purchase_flow/components/company_information.vue';
import ContactBillingAddress from 'ee/subscriptions/shared/components/purchase_flow/components/contact_billing_address.vue';

export default {
  components: {
    CompanyInformation,
    ContactBillingAddress,
  },
  props: {
    billingAccount: {
      type: Object,
      required: true,
    },
  },
};
</script>
<template>
  <div>
    <contact-billing-address
      class="gl-mb-5"
      :is-sold-to-contact="true"
      :contact="billingAccount.soldToContact"
    />
    <contact-billing-address
      class="gl-mb-5"
      :is-sold-to-contact="false"
      :contact="billingAccount.billToContact"
    />

    <company-information class="gl-mb-5" :billing-account="billingAccount" />
  </div>
</template>
