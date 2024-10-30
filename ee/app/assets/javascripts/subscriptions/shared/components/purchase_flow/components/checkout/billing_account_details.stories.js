import { mockBillingAccount } from 'ee_jest/subscriptions/mock_data';
import BillingAccountDetails from './billing_account_details.vue';

export default {
  component: BillingAccountDetails,
  title:
    'ee/subscriptions/shared/components/purchase_flow/components/checkout/billing_account_details',
};

const Template = (args, { argTypes }) => ({
  components: { BillingAccountDetails },
  props: Object.keys(argTypes),
  template: '<billing-account-details v-bind="$props" />',
});

export const Default = Template.bind({});
Default.args = {
  billingAccount: mockBillingAccount,
};
