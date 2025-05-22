import { GlForm, GlButton } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CreateSyncForm from 'ee/roles_and_permissions/components/ldap_sync/create_sync_form.vue';
import ServerFormGroup from 'ee/roles_and_permissions/components/ldap_sync/server_form_group.vue';
import SyncMethodFormGroup from 'ee/roles_and_permissions/components/ldap_sync/sync_method_form_group.vue';
import GroupCnFormGroup from 'ee/roles_and_permissions/components/ldap_sync/group_cn_form_group.vue';
import UserFilterFormGroup from 'ee/roles_and_permissions/components/ldap_sync/user_filter_form_group.vue';
import AdminRoleFormGroup from 'ee/roles_and_permissions/components/ldap_sync/admin_role_form_group.vue';

describe('CreateSyncForm component', () => {
  let wrapper;

  const createWrapper = () => {
    wrapper = shallowMountExtended(CreateSyncForm);
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findServerFormGroup = () => wrapper.findComponent(ServerFormGroup);
  const findSyncMethodFormGroup = () => wrapper.findComponent(SyncMethodFormGroup);
  const findGroupCnFormGroup = () => wrapper.findComponent(GroupCnFormGroup);
  const findUserFilterFormGroup = () => wrapper.findComponent(UserFilterFormGroup);
  const findAdminRoleFormGroup = () => wrapper.findComponent(AdminRoleFormGroup);

  const findFormButtons = () => wrapper.findAllComponents(GlButton);
  const findCancelButton = () => findFormButtons().at(0);
  const findSubmitButton = () => findFormButtons().at(1);

  const submitForm = () => {
    findSubmitButton().vm.$emit('click');
    return nextTick();
  };

  const selectServer = () => {
    findServerFormGroup().vm.$emit('input', 'ldapmain');
  };

  const selectSyncMethod = (value = 'group_cn') => {
    findSyncMethodFormGroup().vm.$emit('input', value);
    return nextTick();
  };

  const selectGroup = () => {
    findGroupCnFormGroup().vm.$emit('input', 'group1');
  };

  const fillUserFilter = () => {
    findUserFilterFormGroup().vm.$emit('input', 'uid=john,ou=people,dc=example,dc=com');
  };

  const selectAdminRole = () => {
    findAdminRoleFormGroup().vm.$emit('input', 'gid://gitlab/MemberRole/1');
  };

  beforeEach(() => createWrapper());

  describe('form', () => {
    it('shows form', () => {
      expect(findForm().exists()).toBe(true);
    });

    describe.each`
      syncMethod       | isGroupCnShown | isUserFilterShown
      ${'group_cn'}    | ${true}        | ${false}
      ${'user_filter'} | ${false}       | ${true}
    `(
      'when the selected sync method is $syncMethod',
      ({ syncMethod, isGroupCnShown, isUserFilterShown }) => {
        beforeEach(() => selectSyncMethod(syncMethod));

        it('shows/hides group cn form group', () => {
          expect(findGroupCnFormGroup().exists()).toBe(isGroupCnShown);
        });

        it('shows/hides user filter form group', () => {
          expect(findUserFilterFormGroup().exists()).toBe(isUserFilterShown);
        });
      },
    );

    it('passes server to group cn form group', async () => {
      selectServer();
      await selectSyncMethod('group_cn');

      expect(findGroupCnFormGroup().props('server')).toBe('ldapmain');
    });

    it('clears selected group when server is changed', async () => {
      await selectSyncMethod('group_cn');
      findServerFormGroup().vm.$emit('ldapmain');
      findGroupCnFormGroup().vm.$emit('group1');
      findServerFormGroup().vm.$emit('ldapalt');

      expect(findGroupCnFormGroup().props('value')).toBe(null);
    });

    describe('Cancel button', () => {
      it('shows button', () => {
        expect(findCancelButton().text()).toBe('Cancel');
      });

      it('emits cancel event when clicked', () => {
        findCancelButton().vm.$emit('click');

        expect(wrapper.emitted('cancel')).toHaveLength(1);
      });
    });

    describe('Add button', () => {
      it('shows button', () => {
        expect(findSubmitButton().text()).toBe('Add');
        expect(findSubmitButton().props('variant')).toBe('confirm');
      });

      it('does not emit submit event when some fields are invalid', () => {
        submitForm();

        expect(wrapper.emitted('submit')).toBeUndefined();
      });

      it.each`
        syncMethod       | fillField         | expectedFieldData
        ${'group_cn'}    | ${selectGroup}    | ${{ groupCn: 'group1' }}
        ${'user_filter'} | ${fillUserFilter} | ${{ userFilter: 'uid=john,ou=people,dc=example,dc=com' }}
      `(
        'emits submit event when sync method is $syncMethod and all fields are filled',
        async ({ syncMethod, fillField, expectedFieldData }) => {
          selectServer();
          await selectSyncMethod(syncMethod);
          fillField();
          selectAdminRole();
          submitForm();

          expect(wrapper.emitted('submit')).toHaveLength(1);
          expect(wrapper.emitted('submit')[0][0]).toEqual({
            server: 'ldapmain',
            ...expectedFieldData,
            roleId: 'gid://gitlab/MemberRole/1',
          });
        },
      );
    });

    describe('form groups and validation', () => {
      describe.each`
        name             | findFormGroup              | syncMethod       | fillField           | expectedValue
        ${'server'}      | ${findServerFormGroup}     | ${null}          | ${selectServer}     | ${'ldapmain'}
        ${'sync method'} | ${findSyncMethodFormGroup} | ${null}          | ${selectSyncMethod} | ${'group_cn'}
        ${'group cn'}    | ${findGroupCnFormGroup}    | ${'group_cn'}    | ${selectGroup}      | ${'group1'}
        ${'user filter'} | ${findUserFilterFormGroup} | ${'user_filter'} | ${fillUserFilter}   | ${'uid=john,ou=people,dc=example,dc=com'}
        ${'admin role'}  | ${findAdminRoleFormGroup}  | ${null}          | ${selectAdminRole}  | ${'gid://gitlab/MemberRole/1'}
      `('$name form group', ({ syncMethod, findFormGroup, fillField, expectedValue }) => {
        beforeEach(() => {
          createWrapper();
          return selectSyncMethod(syncMethod);
        });

        it('shows form group', () => {
          expect(findFormGroup().props()).toMatchObject({ value: null, state: true });
        });

        it('shows form group as invalid when form is submitted', async () => {
          await submitForm();

          expect(findFormGroup().props('state')).toBe(false);
        });

        describe('when field is filled', () => {
          beforeEach(() => {
            submitForm();
            fillField();
          });

          it('shows form group as valid', () => {
            expect(findFormGroup().props('state')).toBe(true);
          });

          it('passes value to form group', () => {
            expect(findFormGroup().props('value')).toBe(expectedValue);
          });
        });
      });
    });

    describe.each`
      oldSyncMethod    | findOldFormGroup           | newSyncMethod    | findNewFormGroup
      ${'group_cn'}    | ${findGroupCnFormGroup}    | ${'user_filter'} | ${findUserFilterFormGroup}
      ${'user_filter'} | ${findUserFilterFormGroup} | ${'group_cn'}    | ${findGroupCnFormGroup}
    `(
      'when $oldSyncMethod is selected and form is submitted',
      ({ oldSyncMethod, findOldFormGroup, newSyncMethod, findNewFormGroup }) => {
        beforeEach(async () => {
          createWrapper();
          await selectSyncMethod(oldSyncMethod);
          return submitForm();
        });

        it('shows old form group as invalid', () => {
          expect(findOldFormGroup().props('state')).toBe(false);
        });

        describe(`when sync method is changed to ${newSyncMethod}`, () => {
          beforeEach(() => selectSyncMethod(newSyncMethod));

          it('shows new form group as valid', () => {
            expect(findNewFormGroup().props('state')).toBe(true);
          });

          it('shows new form group as invalid when input becomes invalid', async () => {
            findNewFormGroup().vm.$emit('input', '');
            await nextTick();

            expect(findNewFormGroup().props('state')).toBe(false);
          });

          it('shows new form group as invalid when form is submitted without valid value', async () => {
            await submitForm();

            expect(findNewFormGroup().props('state')).toBe(false);
          });
        });
      },
    );
  });
});
