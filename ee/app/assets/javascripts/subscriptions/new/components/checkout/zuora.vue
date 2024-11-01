<!-- eslint-disable vue/multi-word-component-names -->
<script>
import { GlLoadingIcon } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import Tracking from '~/tracking';
import { extractErrorCode } from 'ee/subscriptions/shared/components/purchase_flow/zuora_utils';
import { ZUORA_SCRIPT_URL, ZUORA_IFRAME_OVERRIDE_PARAMS } from 'ee/subscriptions/constants';

export default {
  components: {
    GlLoadingIcon,
  },
  mixins: [Tracking.mixin({ category: 'Zuora_cc' })],
  props: {
    active: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['success', 'error'],
  computed: {
    ...mapState([
      'paymentFormParams',
      'paymentMethodId',
      'creditCardDetails',
      'isLoadingPaymentMethod',
    ]),
  },
  watch: {
    // The Zuora script has loaded and the parameters for rendering the iframe have been fetched.
    paymentFormParams() {
      this.renderZuoraIframe();
    },
  },
  mounted() {
    this.loadZuoraScript();
  },
  methods: {
    ...mapActions([
      'startLoadingZuoraScript',
      'fetchPaymentFormParams',
      'zuoraIframeRendered',
      'paymentFormSubmitted',
    ]),
    trackError(errorMessage) {
      this.$emit('error', errorMessage);
      this.track('error', {
        label: 'payment_form_submitted',
        property: errorMessage,
      });
    },
    trackSuccess() {
      this.$emit('success');
    },
    loadZuoraScript() {
      this.startLoadingZuoraScript();

      if (!window.Z) {
        const zuoraScript = document.createElement('script');
        zuoraScript.type = 'text/javascript';
        zuoraScript.async = true;
        zuoraScript.onload = this.fetchPaymentFormParams;
        zuoraScript.src = ZUORA_SCRIPT_URL;
        document.head.appendChild(zuoraScript);
      } else {
        this.fetchPaymentFormParams();
      }
    },
    /*
      For error handling, refer to below Zuora documentation:
      https://knowledgecenter.zuora.com/Billing/Billing_and_Payments/LA_Hosted_Payment_Pages/B_Payment_Pages_2.0/N_Error_Handling_for_Payment_Pages_2.0/Customize_Error_Messages_for_Payment_Pages_2.0#Define_Custom_Error_Message_Handling_Function
      https://knowledgecenter.zuora.com/Billing/Billing_and_Payments/LA_Hosted_Payment_Pages/B_Payment_Pages_2.0/H_Integrate_Payment_Pages_2.0/A_Advanced_Integration_of_Payment_Pages_2.0#Customize_Error_Messages_in_Advanced_Integration
    */
    handleErrorMessage(_key, code, errorMessage) {
      let errorCode = code;
      const extractedCode = extractErrorCode(errorMessage);
      if (extractedCode) {
        errorCode = extractedCode;
      }
      // Success/error is handled in the store actions
      // Use same response format as in `handleZuoraCallback`
      this.paymentFormSubmitted({ errorMessage, errorCode });
      this.trackError(errorMessage);
    },
    handleZuoraCallback(response) {
      this.paymentFormSubmitted(response);
      if (response?.success === 'true') {
        this.trackSuccess();
      } else {
        this.trackError(response?.errorMessage);
      }
    },
    renderZuoraIframe() {
      const params = { ...this.paymentFormParams, ...ZUORA_IFRAME_OVERRIDE_PARAMS };
      window.Z.runAfterRender(() => {
        this.zuoraIframeRendered();
        this.track('iframe_loaded');
      });
      window.Z.renderWithErrorHandler(
        params,
        {},
        this.handleZuoraCallback,
        this.handleErrorMessage,
      );
    },
  },
};
</script>
<template>
  <div>
    <gl-loading-icon v-if="isLoadingPaymentMethod" size="lg" />
    <div v-show="active && !isLoadingPaymentMethod" id="zuora_payment"></div>
  </div>
</template>
