import { GlForm, GlButton } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CreateSyncForm from 'ee/roles_and_permissions/components/ldap_sync/create_sync_form.vue';
import ServerFormGroup from 'ee/roles_and_permissions/components/ldap_sync/server_form_group.vue';

describe('CreateSyncForm component', () => {
  let wrapper;

  const createWrapper = () => {
    wrapper = shallowMountExtended(CreateSyncForm);
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findServerFormGroup = () => wrapper.findComponent(ServerFormGroup);

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

  beforeEach(() => createWrapper());

  describe('form', () => {
    it('shows form', () => {
      expect(findForm().exists()).toBe(true);
    });

    it.each`
      name        | findFormGroup
      ${'server'} | ${findServerFormGroup}
    `('shows $name form group', ({ findFormGroup }) => {
      expect(findFormGroup().props()).toMatchObject({ value: null, state: true });
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

      it('emits submit event when all fields are filled', () => {
        selectServer();
        submitForm();

        expect(wrapper.emitted('submit')).toHaveLength(1);
        expect(wrapper.emitted('submit')[0][0]).toEqual({ server: 'ldapmain' });
      });
    });

    describe('form validation', () => {
      describe.each`
        name        | findFormGroup          | fillField       | expectedValue
        ${'server'} | ${findServerFormGroup} | ${selectServer} | ${'ldapmain'}
      `('$name form group', ({ findFormGroup, fillField, expectedValue }) => {
        beforeEach(() => {
          createWrapper();
        });

        it('shows form group as valid on page load', () => {
          expect(findFormGroup().props('state')).toBe(true);
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
  });
});
