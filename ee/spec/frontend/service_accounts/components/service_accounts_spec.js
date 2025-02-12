import Vue from 'vue';
import { PiniaVuePlugin } from 'pinia';
import { GlButton, GlDisclosureDropdown, GlPagination, GlTable } from '@gitlab/ui';
import { createTestingPinia } from '@pinia/testing';
import { mountExtended } from 'helpers/vue_test_utils_helper';

import { useServiceAccounts } from 'ee/service_accounts/stores/service_accounts';
import ServiceAccounts from 'ee/service_accounts/components/service_accounts/service_accounts.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { TEST_HOST } from 'helpers/test_constants';

Vue.use(PiniaVuePlugin);

let wrapper;

const findPagination = () => wrapper.findComponent(GlPagination);
const findPageHeading = () => wrapper.findComponent(PageHeading);
const findAddServiceAccountButton = () => findPageHeading().findComponent(GlButton);
const findTable = () => wrapper.findComponent(GlTable);
const findDisclosure = () => wrapper.findComponent(GlDisclosureDropdown);

describe('Service Accounts', () => {
  const serviceAccountsPath = `${TEST_HOST}/service_accounts`;
  const serviceAccountsDocsPath = `${TEST_HOST}/ee/user/profile/service_accounts.html`;

  const pinia = createTestingPinia();
  const store = useServiceAccounts();

  const createComponent = () => {
    wrapper = mountExtended(ServiceAccounts, {
      pinia,
      stubs: {},
      provide: {
        serviceAccountsPath,
        serviceAccountsDocsPath,
      },
    });
  };

  beforeAll(() => {
    store.serviceAccounts = [{ name: 'Service Account 1', username: 'test user' }];
  });

  beforeEach(() => {
    createComponent();
  });

  it('fetches service accounts when it is rendered', () => {
    expect(store.fetchServiceAccounts).toHaveBeenCalledWith(serviceAccountsPath, {
      page: 1,
      perPage: 8,
    });
  });

  it('fetches service accounts when the page is changed', () => {
    findPagination().vm.$emit('input', 2);

    expect(store.fetchServiceAccounts).toHaveBeenCalledWith(serviceAccountsPath, {
      page: 2,
      perPage: 8,
    });
  });

  describe('table', () => {
    describe('busy state', () => {
      describe('when it is `true`', () => {
        beforeAll(() => {
          store.busy = true;
        });

        afterAll(() => {
          store.busy = false;
        });

        it('has aria-busy `true` in the table', () => {
          expect(findTable().attributes('aria-busy')).toBe('true');
        });

        it('disables the dropdown', () => {
          expect(findDisclosure().props('disabled')).toBe(true);
        });
      });

      describe('when it is `false`', () => {
        it('has aria-busy `false` in the table', () => {
          expect(findTable().attributes('aria-busy')).toBe('false');
        });

        it('enables the dropdown', () => {
          expect(findDisclosure().props('disabled')).toBe(false);
        });
      });
    });

    describe('headers', () => {
      it('should have name', () => {
        const header = wrapper.findByTestId('header-name');
        expect(header.text()).toBe('Name');
      });
    });

    describe('cells', () => {
      describe('name', () => {
        it('shows the service account name and username', () => {
          const name = wrapper.findByTestId('service-account-name');
          const username = wrapper.findByTestId('service-account-username');
          expect(name.text()).toBe('Service Account 1');
          expect(username.text()).toBe('test user');
        });
      });

      describe('options', () => {
        it('shows the options dropdown', () => {
          const options = wrapper.findByTestId('cell-options').findComponent(GlDisclosureDropdown);
          expect(options.props('items')).toEqual([
            {
              text: 'Manage Access Tokens',
            },
            {
              text: 'Edit',
            },
            {
              text: 'Delete Account',
              variant: 'danger',
            },
            {
              text: 'Delete Account and Contributions',
              variant: 'danger',
            },
          ]);
        });
      });
    });
  });

  describe('header', () => {
    it('shows the page heading', () => {
      const heading = findPageHeading();
      expect(heading.text()).toContain(
        'Service accounts are non-human accounts that allow interactions between software applications, systems, or services. Learn more',
      );
    });

    it('triggers the add service account action', () => {
      const addServiceAccountButton = findAddServiceAccountButton();

      addServiceAccountButton.vm.$emit('click');

      expect(addServiceAccountButton.emitted()).toHaveProperty('click');
      expect(store.addServiceAccount).toHaveBeenCalled();
    });
  });
});
