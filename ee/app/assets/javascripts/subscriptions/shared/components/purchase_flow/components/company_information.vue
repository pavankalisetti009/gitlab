<script>
import { s__ } from '~/locale';

export default {
  props: {
    billingAccount: {
      required: true,
      type: Object,
    },
  },
  i18n: {
    title: s__('Checkout|Company information'),
    taxId: s__('Checkout|Tax ID'),
  },
};
</script>
<template>
  <div data-testid="billing-account-company-wrapper">
    <h6>{{ $options.i18n.title }}</h6>

    <div data-testid="billing-account-company-name">{{ billingAccount.zuoraAccountName }}</div>
    <div v-if="billingAccount.vatFieldVisible" data-testid="billing-account-tax-id">
      {{ $options.i18n.taxId }}: {{ billingAccount.zuoraAccountVatId }}
    </div>
  </div>
</template>
