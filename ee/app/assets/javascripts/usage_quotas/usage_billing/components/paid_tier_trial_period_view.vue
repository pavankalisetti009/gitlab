<script>
import { GlButton, GlLink, GlCard, GlSprintf } from '@gitlab/ui';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';

export default {
  name: 'PaidTierTrialPeriodView',
  components: {
    GlButton,
    GlCard,
    GlLink,
    GlSprintf,
    HelpPageLink,
  },
  props: {
    customersUsageDashboardUrl: {
      type: String,
      required: true,
    },
    purchaseCreditsUrl: {
      required: false,
      type: String,
      default: null,
    },
  },
};
</script>
<template>
  <section class="gl-flex gl-flex-col gl-gap-5">
    <gl-card
      class="gl-w-full gl-bg-transparent"
      body-class="gl-p-6 gl-flex gl-flex-col gl-items-start gl-justify-between gl-gap-4"
      data-testid="paid-tier-trial-header-card"
    >
      <div>
        <h2 class="gl-heading-scale-500 gl-mb-3">
          {{ s__('UsageBilling|Your GitLab evaluation credits are active') }}
        </h2>

        <p>
          <gl-sprintf
            :message="
              s__(
                'UsageBilling|You are currently using temporary evaluation credits to access GitLab Duo features. Your subscription\'s included credits for users will be available after your evaluation ends. If you have access to the %{linkStart}Customers Portal%{linkEnd}, you can view your usage breakdown, remaining balance, and some usage details.',
              )
            "
          >
            <template #link="{ content }">
              <help-page-link
                href="subscriptions/billing_account"
                anchor="sign-in-to-customers-portal"
                target="_blank"
                >{{ content }}</help-page-link
              >
            </template>
          </gl-sprintf>
        </p>
      </div>
      <div class="gl-mt-auto">
        <gl-button
          :href="customersUsageDashboardUrl"
          category="primary"
          variant="confirm"
          icon="external-link"
          target="_blank"
          class="gl-whitespace-nowrap"
        >
          {{ s__('UsageBilling|Go to Customers Portal') }}
        </gl-button>
      </div>
    </gl-card>

    <slot name="chart"></slot>

    <section
      class="gl-flex gl-flex-col gl-gap-5 @md/panel:gl-flex-row"
      data-testid="paid-tier-trial-body"
    >
      <gl-card v-if="purchaseCreditsUrl" class="gl-flex-1 gl-bg-subtle" body-class="gl-p-6">
        <h2 class="gl-heading-scale-400 gl-mb-2">
          {{ s__('UsageBilling|Continue after your evaluation') }}
        </h2>

        <p>
          {{
            s__(
              'UsageBilling|Monthly commitments offer significant discounts off list price. Pool GitLab Credits across your namespace for flexibility and predictable monthly costs.',
            )
          }}
        </p>

        <div class="gl-mt-auto">
          <gl-link category="tertiary" :href="purchaseCreditsUrl">
            {{ s__('UsageBilling|Purchase monthly commitment') }}
          </gl-link>
        </div>
      </gl-card>

      <gl-card class="gl-flex-1 gl-bg-subtle" body-class="gl-p-6">
        <h2 class="gl-heading-scale-400 gl-mb-2">
          {{ s__('UsageBilling|Learn about GitLab Credits') }}
        </h2>

        <p>
          {{
            s__(
              "UsageBilling|Understand how credits are consumed by different features, explore your billing and commitment options, and learn how to monitor your members' usage.",
            )
          }}
        </p>

        <div class="gl-mt-auto">
          <help-page-link href="subscriptions/gitlab_credits" target="_blank">{{
            s__('UsageBilling|Read the documentation')
          }}</help-page-link>
        </div>
      </gl-card>

      <gl-card class="gl-subtle gl-flex-1" body-class="gl-p-6">
        <h2 class="gl-heading-scale-400 gl-mb-2">
          {{ s__('UsageBilling|Explore GitLab Duo') }}
        </h2>

        <p>
          {{
            s__(
              'UsageBilling|Try the GitLab Duo Agent Platform and agentic chat to delegate routine tasks like code refactoring, security scans, and research to AI-powered assistants.',
            )
          }}
        </p>

        <div class="gl-mt-auto">
          <help-page-link href="user/gitlab_duo/_index" target="_blank">{{
            s__('UsageBilling|Learn more about GitLab Duo')
          }}</help-page-link>
        </div>
      </gl-card>
    </section>
  </section>
</template>
