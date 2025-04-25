import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlLink, GlButton, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ldapAdminRoleLinksQuery from 'ee/roles_and_permissions/graphql/ldap_sync/ldap_admin_role_links.query.graphql';
import LdapSyncCrud from 'ee/roles_and_permissions/components/ldap_sync/ldap_sync_crud.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { ldapAdminRoleLinks } from '../../mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('LdapSyncCrud component', () => {
  let wrapper;

  const getRoleLinksHandler = (nodes = ldapAdminRoleLinks) =>
    jest.fn().mockResolvedValue({ data: { ldapAdminRoleLinks: { nodes } } });
  const defaultRoleLinksHandler = getRoleLinksHandler();

  const createWrapper = ({ roleLinksHandler = defaultRoleLinksHandler } = {}) => {
    wrapper = shallowMountExtended(LdapSyncCrud, {
      apolloProvider: createMockApollo([[ldapAdminRoleLinksQuery, roleLinksHandler]]),
      stubs: { CrudComponent, GlSprintf },
    });

    return waitForPromises();
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findCrudComponent = () => wrapper.findComponent(CrudComponent);
  const findCrudActions = () => wrapper.findByTestId('crud-actions');
  const findCrudBody = () => wrapper.findByTestId('crud-body');
  const findLdapUsersLink = () => findCrudActions().findComponent(GlLink);
  const findActionButtons = () => findCrudActions().findAllComponents(GlButton);
  const findRoleLinksList = () => findCrudBody().find('ul');
  const findRoleLinkItems = () => findRoleLinksList().findAll('li');

  describe('crud component', () => {
    beforeEach(() => createWrapper());

    it('shows title', () => {
      expect(findCrudComponent().props('title')).toBe('Active synchronizations');
    });

    it('shows description', () => {
      expect(findCrudComponent().props('description')).toBe(
        'Automatically sync your LDAP directory to custom admin roles.',
      );
    });
  });

  describe('on page load', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('calls ldap role links query', () => {
      expect(defaultRoleLinksHandler).toHaveBeenCalledTimes(1);
    });

    it('does not show alert', () => {
      expect(findAlert().exists()).toBe(false);
    });

    it('shows crud component as busy', () => {
      expect(findCrudComponent().props('isLoading')).toBe(true);
    });

    it('does not show crud actions', () => {
      expect(findLdapUsersLink().exists()).toBe(false);
      expect(findActionButtons()).toHaveLength(0);
    });
  });

  describe('when ldap role links could not be loaded', () => {
    beforeEach(() => createWrapper({ roleLinksHandler: jest.fn().mockRejectedValue }));

    it('shows alert', () => {
      expect(findAlert().props()).toMatchObject({ variant: 'danger', dismissible: false });
      expect(findAlert().text()).toBe(
        'Could not load LDAP synchronizations. Please refresh the page to try again.',
      );
    });

    it('does not show crud component', () => {
      expect(findCrudComponent().exists()).toBe(false);
    });
  });

  describe('when there are no ldap role links', () => {
    beforeEach(() => createWrapper({ roleLinksHandler: getRoleLinksHandler([]) }));

    it('does not show alert', () => {
      expect(findAlert().exists()).toBe(false);
    });

    it('does not show role links list', () => {
      expect(findRoleLinksList().exists()).toBe(false);
    });

    it('shows zero for the count', () => {
      expect(findCrudComponent().props('count')).toBe(0);
    });

    it('shows no synchronizations message', () => {
      expect(findCrudBody().text()).toBe(
        'No active LDAP synchronizations. Add synchronization to connect your LDAP directory with custom admin roles.',
      );
    });

    describe('crud actions', () => {
      it('does not show ldap users link', () => {
        expect(findLdapUsersLink().exists()).toBe(false);
      });

      it('only shows Add synchronization button', () => {
        expect(findActionButtons()).toHaveLength(1);
        expect(findActionButtons().at(0).props('variant')).toBe('confirm');
        expect(findActionButtons().at(0).text()).toBe('Add synchronization');
      });
    });
  });

  describe('when there are ldap role links', () => {
    beforeEach(() => createWrapper());

    it('does not show alert', () => {
      expect(findAlert().exists()).toBe(false);
    });

    it('does not show no synchronizations message', () => {
      expect(findCrudBody().text()).not.toContain(
        'No active LDAP synchronizations. Add synchronization to connect your LDAP directory with custom admin roles.',
      );
    });

    it('shows the correct count', () => {
      expect(findCrudComponent().props('count')).toBe(2);
    });

    describe('crud actions', () => {
      it('shows "View LDAP synced users" link', () => {
        expect(findLdapUsersLink().text()).toBe('View LDAP synced users');
      });

      it('shows Sync all button', () => {
        const button = findActionButtons().at(0);

        expect(button.props('icon')).toBe('retry');
        expect(button.text()).toBe('Sync all');
      });

      it('shows Add Synchronization button', () => {
        const button = findActionButtons().at(1);

        expect(button.props('variant')).toBe('confirm');
        expect(button.text()).toBe('Add synchronization');
      });
    });

    it('shows role links list', () => {
      expect(findRoleLinksList().exists()).toBe(true);
    });

    it('shows 2 role link items', () => {
      expect(findRoleLinkItems()).toHaveLength(2);
    });

    describe.each`
      index | server        | filterLabel       | filterValue                                | role
      ${0}  | ${'LDAP'}     | ${'User filter:'} | ${'cn=group1,ou=groups,dc=example,dc=com'} | ${'Custom admin role 1'}
      ${1}  | ${'LDAP alt'} | ${'Group cn:'}    | ${'group2'}                                | ${'Custom admin role 2'}
    `('for role link item $index', ({ index, server, filterLabel, filterValue, role }) => {
      let listItem;
      let dtList;
      let ddList;

      beforeEach(() => {
        listItem = findRoleLinkItems().at(index);
        dtList = listItem.findAll('dt');
        ddList = listItem.findAll('dd');
      });

      describe('server name', () => {
        it('shows label', () => {
          expect(dtList.at(0).text()).toBe('Server:');
        });

        it('shows name', () => {
          expect(ddList.at(0).text()).toBe(server);
        });
      });

      describe('filter', () => {
        it('shows label', () => {
          expect(dtList.at(1).text()).toBe(filterLabel);
        });

        it('shows value', () => {
          expect(ddList.at(1).text()).toBe(filterValue);
        });
      });

      describe('custom role name', () => {
        it('shows label', () => {
          expect(dtList.at(2).text()).toBe('Custom admin role:');
        });

        it('shows value', () => {
          expect(ddList.at(2).text()).toBe(role);
        });
      });

      describe('actions', () => {
        let actionsDiv;

        beforeEach(() => {
          actionsDiv = listItem.find('div');
        });

        it('shows delete button', () => {
          const button = actionsDiv.findComponent(GlButton);
          expect(button.attributes('aria-label')).toBe('Remove sync');
          expect(button.props()).toMatchObject({
            variant: 'danger',
            icon: 'remove',
            category: 'secondary',
          });
        });

        it('shows last synced text', () => {
          expect(actionsDiv.find('span').text()).toBe('Last synced: Never');
        });
      });
    });
  });
});
