import ContactBillingAddress from 'ee/subscriptions/shared/components/purchase_flow/components/contact_billing_address.vue';
import { mockBillingAccount } from 'ee_jest/subscriptions/mock_data';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('Company information', () => {
  let wrapper;

  const createComponent = (propsData) => {
    wrapper = shallowMountExtended(ContactBillingAddress, {
      propsData,
    });
  };

  const findTitle = () => wrapper.find('h6');
  const findContactName = () => wrapper.findByTestId('billing-contact-full-name');
  const findContactEmail = () => wrapper.findByTestId('billing-contact-work-email');
  const findContactAddress1 = () => wrapper.findByTestId('billing-contact-address1');
  const findContactAddress2 = () => wrapper.findByTestId('billing-contact-address2');
  const findContactCityState = () => wrapper.findByTestId('billing-contact-city-state');
  const findContactPostalCode = () => wrapper.findByTestId('billing-contact-postal-code');
  const findContactCountry = () => wrapper.findByTestId('billing-contact-country');

  const { soldToContact, billToContact } = mockBillingAccount;

  describe.each`
    testCaseName              | isSoldToContact | contact
    ${'with sold to contact'} | ${true}         | ${soldToContact}
    ${'with bill to contact'} | ${false}        | ${billToContact}
  `('$testCaseName', ({ isSoldToContact, contact }) => {
    beforeEach(() => {
      createComponent({ isSoldToContact, contact });
    });

    it('shows title', () => {
      expect(findTitle().exists()).toBe(true);
    });

    describe('contact name', () => {
      it('shows', () => {
        expect(findContactName().exists()).toBe(true);
      });

      it('has correct name', () => {
        expect(findContactName().text()).toEqual(soldToContact.fullName);
      });
    });

    it('shows email', () => {
      expect(findContactEmail().exists()).toBe(true);
    });

    it('shows address1', () => {
      expect(findContactAddress1().exists()).toBe(true);
    });

    it('shows address2', () => {
      expect(findContactAddress2().exists()).toBe(true);
    });

    it('shows city and state', () => {
      expect(findContactCityState().exists()).toBe(true);
    });

    it('shows postal code', () => {
      expect(findContactPostalCode().exists()).toBe(true);
    });

    it('shows country', () => {
      expect(findContactCountry().exists()).toBe(true);
    });
  });

  it('does not show address1 if not present', () => {
    const contact = { ...soldToContact, address1: '' };
    createComponent({ isSoldToContact: true, contact });
    expect(findContactAddress1().exists()).toBe(false);
  });

  it('does not show address2 if not present', () => {
    const contact = { ...soldToContact, address2: '' };
    createComponent({ isSoldToContact: false, contact });
    expect(findContactAddress2().exists()).toBe(false);
  });

  it('shows first and last name if fullName is not populated', () => {
    const contact = { ...soldToContact, fullName: '' };
    createComponent({ isSoldToContact: true, contact });

    expect(findContactName().exists()).toBe(true);
    expect(findContactName().text()).toBe(`${soldToContact.firstName} ${soldToContact.lastName}`);
  });
});
