import Vue from 'vue';
import { PiniaVuePlugin } from 'pinia';
import { GlButton, GlDisclosureDropdown, GlPagination, GlTable } from '@gitlab/ui';
import { createTestingPinia } from '@pinia/testing';
import { mountExtended } from 'helpers/vue_test_utils_helper';

import { useServiceAccounts } from 'ee/service_accounts/stores/service_accounts';
import DeleteServiceAccountModal from 'ee/service_accounts/components/service_accounts/delete_service_account_modal.vue';
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
const findDisclosureButton = (index) =>
  findDisclosure().findAll('button.gl-new-dropdown-item-content').at(index);
const findModal = () => wrapper.findComponent(DeleteServiceAccountModal);

describe('Service Accounts', () => {
  const serviceAccountsPath = `${TEST_HOST}/service_accounts`;
  const serviceAccountsDeletePath = '/api/v4/users';
  const serviceAccountsDocsPath = `${TEST_HOST}/ee/user/profile/service_accounts.html`;

  const pinia = createTestingPinia();
  const store = useServiceAccounts();

  const $router = {
    push: jest.fn(),
  };

  const createComponent = () => {
    wrapper = mountExtended(ServiceAccounts, {
      pinia,
      mocks: {
        $router,
      },
      provide: {
        serviceAccountsPath,
        serviceAccountsDeletePath,
        serviceAccountsDocsPath,
      },
    });
  };

  beforeAll(() => {
    store.serviceAccounts = [{ id: 1, name: 'Service Account 1', username: 'test user' }];
  });

  beforeEach(() => {
    createComponent();
  });

  it('fetches service accounts when it is rendered', () => {
    expect(store.fetchServiceAccounts).toHaveBeenCalledWith(serviceAccountsPath, { page: 1 });
  });

  it('fetches service accounts when the page is changed', () => {
    findPagination().vm.$emit('input', 2);

    expect(store.fetchServiceAccounts).toHaveBeenCalledWith(serviceAccountsPath, { page: 2 });
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
          expect(options.props('items')).toMatchObject([
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

        it('routes to the token management when click on manage access token button', () => {
          findDisclosureButton(0).trigger('click');

          expect($router.push).toHaveBeenCalledWith({
            name: 'access_tokens',
            params: { id: 1 },
            replace: true,
          });
        });

        it('set the account and delete type when click on the delete account button', () => {
          findDisclosureButton(2).trigger('click');

          expect(store.setServiceAccount).toHaveBeenCalledWith({
            id: 1,
            name: 'Service Account 1',
            username: 'test user',
          });
          expect(store.setDeleteType).toHaveBeenCalledWith('soft');
        });

        it('set the account and delete type when click on the delete account and contribution button', () => {
          findDisclosureButton(3).trigger('click');

          expect(store.setServiceAccount).toHaveBeenCalledWith({
            id: 1,
            name: 'Service Account 1',
            username: 'test user',
          });
          expect(store.setDeleteType).toHaveBeenCalledWith('hard');
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

  describe('modal', () => {
    beforeEach(() => {
      store.deleteType = 'soft';
      store.serviceAccount = {
        id: 1,
        name: 'Service Account 1',
        username: 'test user',
      };
      createComponent();
    });

    it('shows the modal when the delete button is clicked', () => {
      expect(findModal().exists()).toBe(true);
    });

    it('call deleteUser when modal is submitted', () => {
      findModal().vm.$emit('submit');

      expect(store.deleteUser).toHaveBeenCalledWith(serviceAccountsDeletePath);
    });

    it('resets deleteType when modal is cancelled', () => {
      findModal().vm.$emit('cancel');

      expect(store.setDeleteType).toHaveBeenCalledWith(null);
    });
  });
});
