import { mockBillingAccount } from 'ee_jest/subscriptions/mock_data';
import ContactBillingAddress from './contact_billing_address.vue';

export default {
  component: ContactBillingAddress,
  title: 'ee/subscriptions/shared/components/purchase_flow/components/contact_billing_address',
};

const Template = (args, { argTypes }) => ({
  components: { ContactBillingAddress },
  props: Object.keys(argTypes),
  template: '<contact-billing-address v-bind="$props" />',
});

export const SoldToContact = Template.bind({});
SoldToContact.args = {
  isSoldToContact: true,
  contact: mockBillingAccount.soldToContact,
};

export const BillToContact = Template.bind({});
BillToContact.args = {
  isSoldToContact: false,
  contact: mockBillingAccount.soldToContact,
};
