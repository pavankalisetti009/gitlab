<script>
import { GlCard, GlTabs, GlTab } from '@gitlab/ui';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import PurchaseCommitmentCard from './purchase_commitment_card.vue';

export default {
  name: 'UsageBillingApp',
  components: {
    GlCard,
    GlTabs,
    GlTab,
    PageHeading,
    PurchaseCommitmentCard,
  },
};
</script>
<template>
  <section>
    <page-heading>
      <template #heading>
        <span data-testid="usage-billing-title">{{ s__('UsageBilling|Usage Billing') }}</span>
      </template>
    </page-heading>

    <section class="gl-flex gl-flex-col gl-gap-5 md:gl-flex-row">
      <gl-card class="gl-flex-1 gl-bg-transparent">
        <h2 class="gl-font-heading gl-heading-scale-400 gl-mb-3">
          {{ s__('UsageBilling|Current month usage') }}
        </h2>
      </gl-card>

      <purchase-commitment-card />
    </section>
    <gl-tabs class="gl-mt-5">
      <gl-tab :title="s__('UsageBilling|Usage trends')">
        {{ s__('UsageBilling|Usage trends') }}
      </gl-tab>
      <gl-tab :title="s__('UsageBilling|Usage by user')">
        {{ s__('UsageBilling|Usage by user') }}
      </gl-tab>
    </gl-tabs>
  </section>
</template>
