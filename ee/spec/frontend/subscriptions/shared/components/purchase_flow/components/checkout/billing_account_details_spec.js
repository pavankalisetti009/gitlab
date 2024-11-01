import { shallowMount } from '@vue/test-utils';
import CompanyInformation from 'ee/subscriptions/shared/components/purchase_flow/components/company_information.vue';
import ContactBillingAddress from 'ee/subscriptions/shared/components/purchase_flow/components/contact_billing_address.vue';
import BillingAccountDetails from 'ee/subscriptions/shared/components/purchase_flow/components/checkout/billing_account_details.vue';
import { mockBillingAccount } from 'ee_jest/subscriptions/mock_data';

describe('Billing account details', () => {
  let wrapper;

  const findAllContactBillingAddress = () => wrapper.findAllComponents(ContactBillingAddress);
  const findCompanyInformation = () => wrapper.findComponent(CompanyInformation);

  const { soldToContact, billToContact } = mockBillingAccount;

  const createComponent = () => {
    wrapper = shallowMount(BillingAccountDetails, {
      propsData: { billingAccount: mockBillingAccount },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders correct number of ContactBillingAddress components', () => {
    expect(findAllContactBillingAddress()).toHaveLength(2);
  });

  it('passes correct props to sold to ContactBillingAddress component', () => {
    expect(findAllContactBillingAddress().at(0).props()).toMatchObject({
      isSoldToContact: true,
      contact: soldToContact,
    });
  });

  it('passes correct props to bill to ContactBillingAddress component', () => {
    expect(findAllContactBillingAddress().at(1).props()).toMatchObject({
      isSoldToContact: false,
      contact: billToContact,
    });
  });

  it('renders company information', () => {
    expect(findCompanyInformation().exists()).toBe(true);
  });
});
