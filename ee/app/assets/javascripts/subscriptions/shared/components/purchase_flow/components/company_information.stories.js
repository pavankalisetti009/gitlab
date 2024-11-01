import { mockBillingAccount } from 'ee_jest/subscriptions/mock_data';
import CompanyInformation from './company_information.vue';

export default {
  component: CompanyInformation,
  title: 'ee/subscriptions/shared/components/purchase_flow/components/company_information',
};

const Template = (args, { argTypes }) => ({
  components: { CompanyInformation },
  props: Object.keys(argTypes),
  template: '<company-information v-bind="$props" />',
});

export const Default = Template.bind({});
Default.args = {
  billingAccount: mockBillingAccount,
};
