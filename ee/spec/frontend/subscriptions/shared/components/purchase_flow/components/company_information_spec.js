import CompanyInformation from 'ee/subscriptions/shared/components/purchase_flow/components/company_information.vue';
import { mockBillingAccount } from 'ee_jest/subscriptions/mock_data';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

jest.mock('~/lib/logger');

describe('Company information', () => {
  let wrapper;

  const mockBillingAccountWithoutTaxId = { ...mockBillingAccount, vatFieldVisible: false };

  const createComponent = (propsData = { billingAccount: mockBillingAccount }) => {
    wrapper = shallowMountExtended(CompanyInformation, {
      propsData,
    });
  };

  const findCompanyInformationContent = () =>
    wrapper.findByTestId('billing-account-company-wrapper');
  const findTitle = () => wrapper.find('h6');
  const findCompanyName = () => wrapper.findByTestId('billing-account-company-name');
  const findCompanyTaxId = () => wrapper.findByTestId('billing-account-tax-id');

  describe('with a valid billing account', () => {
    describe.each`
      testCaseName        | billingAccount                    | showsTaxId
      ${'with tax ID'}    | ${mockBillingAccount}             | ${true}
      ${'without tax ID'} | ${mockBillingAccountWithoutTaxId} | ${false}
    `('$testCaseName', ({ billingAccount, showsTaxId }) => {
      beforeEach(() => {
        createComponent({ billingAccount });
      });

      it('shows company information content', () => {
        expect(findCompanyInformationContent().exists()).toBe(true);
      });

      it('shows title', () => {
        expect(findTitle().exists()).toBe(true);
      });

      it('shows company name', () => {
        expect(findCompanyName().exists()).toBe(true);
      });

      it(`${showsTaxId ? 'shows' : 'does not show'} company tax ID`, () => {
        expect(findCompanyTaxId().exists()).toBe(showsTaxId);
      });
    });
  });
});
