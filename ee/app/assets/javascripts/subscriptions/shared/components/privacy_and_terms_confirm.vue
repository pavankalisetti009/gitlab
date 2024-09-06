<script>
import { GlFormCheckbox, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import PromoPageLink from '~/vue_shared/components/promo_page_link/promo_page_link.vue';

export default {
  name: 'PrivacyAndTermsConfirm',
  i18n: {
    label: s__(
      'Subscriptions|I accept the %{privacyLinkStart}Privacy Statement%{privacyLinkEnd} and %{termsLinkStart}Terms of Service%{termsLinkEnd}.',
    ),
  },
  helpLinks: {
    privacyPath: '/privacy',
    termsPath: '/terms#subscription',
  },
  components: { GlFormCheckbox, PromoPageLink, GlSprintf },
  props: {
    value: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['input:value'],
  methods: {
    toogleAccepted(value) {
      this.$emit('input', value);
    },
  },
};
</script>
<template>
  <gl-form-checkbox :checked="value" @input="toogleAccepted">
    <gl-sprintf :message="$options.i18n.label">
      <template #privacyLink="{ content }">
        <promo-page-link
          :path="$options.helpLinks.privacyPath"
          target="_blank"
          data-testid="privacy-link"
          >{{ content }}</promo-page-link
        >
      </template>
      <template #termsLink="{ content }">
        <promo-page-link
          :path="$options.helpLinks.termsPath"
          target="_blank"
          data-testid="terms-link"
          >{{ content }}</promo-page-link
        >
      </template>
    </gl-sprintf>
  </gl-form-checkbox>
</template>
