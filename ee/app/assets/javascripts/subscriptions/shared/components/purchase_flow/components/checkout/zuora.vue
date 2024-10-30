<!-- eslint-disable vue/multi-word-component-names -->
<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { pick } from 'lodash';
import Api from 'ee/api';
import {
  ERROR_LOADING_PAYMENT_FORM,
  PAYMENT_FORM_ID,
  ZUORA_IFRAME_OVERRIDE_PARAMS,
  ZUORA_SCRIPT_URL,
} from 'ee/subscriptions/constants';
import updateStateMutation from 'ee/subscriptions/graphql/mutations/update_state.mutation.graphql';
import activateNextStepMutation from 'ee/subscriptions/shared/components/purchase_flow/graphql/mutations/activate_next_step.mutation.graphql';
import { extractErrorCode } from 'ee/subscriptions/shared/components/purchase_flow/zuora_utils';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import Tracking from '~/tracking';
import { PurchaseEvent } from 'ee/subscriptions/new/constants';

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
    accountId: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      isLoading: false,
      paymentFormParams: {},
      zuoraLoaded: false,
      zuoraScriptEl: null,
    };
  },
  computed: {
    shouldShowZuoraFrame() {
      return this.active && this.zuoraLoaded && !this.isLoading;
    },
    renderParams() {
      return {
        ...this.paymentFormParams,
        ...ZUORA_IFRAME_OVERRIDE_PARAMS,
        // @TODO: should the component handle re-rendering the form in case this changes?
        field_accountId: this.accountId,
      };
    },
  },
  mounted() {
    this.loadZuoraScript();
  },
  methods: {
    zuoraIframeRendered() {
      this.isLoading = false;
      this.zuoraLoaded = true;
      this.track('iframe_loaded');
    },
    fetchPaymentFormParams() {
      this.isLoading = true;

      return Api.fetchPaymentFormParams(PAYMENT_FORM_ID)
        .then(({ data }) => {
          this.paymentFormParams = data;
          this.renderZuoraIframe();
        })
        .catch((error) => {
          this.$emit(PurchaseEvent.ERROR, new Error(ERROR_LOADING_PAYMENT_FORM));
          this.track('error', {
            label: 'payment_form_fetch_params',
            property: error?.message,
          });
        });
    },
    loadZuoraScript() {
      this.isLoading = true;

      if (!this.zuoraScriptEl) {
        this.zuoraScriptEl = document.createElement('script');
        this.zuoraScriptEl.type = 'text/javascript';
        this.zuoraScriptEl.async = true;
        this.zuoraScriptEl.onload = this.fetchPaymentFormParams;
        this.zuoraScriptEl.src = ZUORA_SCRIPT_URL;
        document.head.appendChild(this.zuoraScriptEl);
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
      this.$emit(PurchaseEvent.ERROR, new Error(errorMessage, { cause: errorCode }));
      this.track('error', {
        label: 'payment_form_submitted',
        property: errorMessage,
      });
    },
    async handleZuoraCallback(response = {}) {
      this.isLoading = true;
      try {
        const { refId, success, errorMessage } = response;
        if (success !== 'true') {
          throw new Error(errorMessage);
        }
        const { data } = await Api.fetchPaymentMethodDetails(refId);
        const paymentMethodData = pick(
          data,
          'id',
          'credit_card_expiration_month',
          'credit_card_expiration_year',
          'credit_card_type',
          'credit_card_mask_number',
        );
        const paymentMethod = convertObjectPropsToCamelCase(paymentMethodData);
        await this.updateState({ paymentMethod });
        this.track('success', {
          label: 'payment_form_submitted',
        });
        await this.activateNextStep();
      } catch (error) {
        this.$emit(PurchaseEvent.ERROR, error);
        this.track('error', {
          label: 'payment_form_submitted',
          property: error?.message,
        });
      } finally {
        this.isLoading = false;
      }
    },
    renderZuoraIframe() {
      window.Z.runAfterRender(this.zuoraIframeRendered);
      window.Z.renderWithErrorHandler(
        this.renderParams,
        {},
        this.handleZuoraCallback,
        this.handleErrorMessage,
      );
    },
    activateNextStep() {
      return this.$apollo.mutate({
        mutation: activateNextStepMutation,
      });
    },
    updateState(payload) {
      return this.$apollo.mutate({
        mutation: updateStateMutation,
        variables: {
          input: payload,
        },
      });
    },
  },
};
</script>

<template>
  <div>
    <gl-loading-icon v-if="isLoading" size="lg" />
    <div v-show="shouldShowZuoraFrame" id="zuora_payment"></div>
  </div>
</template>
