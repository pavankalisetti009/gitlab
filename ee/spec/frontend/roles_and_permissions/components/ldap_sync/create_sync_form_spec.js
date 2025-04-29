import { GlForm, GlFormGroup, GlButton, GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CreateSyncForm from 'ee/roles_and_permissions/components/ldap_sync/create_sync_form.vue';
import { stubComponent } from 'helpers/stub_component';
import { ldapServers } from '../../mock_data';

describe('CreateSyncForm component', () => {
  let wrapper;

  const createWrapper = () => {
    wrapper = shallowMountExtended(CreateSyncForm, {
      provide: { ldapServers },
      stubs: {
        GlFormGroup: stubComponent(GlFormGroup, { props: ['label', 'state', 'invalidFeedback'] }),
      },
    });
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findFormGroupAt = (index) => wrapper.findAllComponents(GlFormGroup).at(index);
  const findServerFormGroup = () => findFormGroupAt(0);
  const findServerDropdown = () => findFormGroupAt(0).findComponent(GlCollapsibleListbox);
  const findFormButtons = () => wrapper.findAllComponents(GlButton);
  const findCancelButton = () => findFormButtons().at(0);
  const findSubmitButton = () => findFormButtons().at(1);

  beforeEach(() => createWrapper());

  describe('form', () => {
    it('shows form', () => {
      expect(findForm().exists()).toBe(true);
    });

    describe('cancel button', () => {
      it('shows button', () => {
        expect(findCancelButton().text()).toBe('Cancel');
      });

      it('emits cancel event when clicked', () => {
        findCancelButton().vm.$emit('click');

        expect(wrapper.emitted('cancel')).toHaveLength(1);
      });
    });

    describe('add button', () => {
      it('shows button', () => {
        expect(findSubmitButton().text()).toBe('Add');
        expect(findSubmitButton().props('variant')).toBe('confirm');
      });

      it('does not emit submit event when some fields are invalid', () => {
        findSubmitButton().vm.$emit('click');

        expect(wrapper.emitted('submit')).toBeUndefined();
      });

      it('emits submit event when all fields are valid', () => {
        findServerDropdown().vm.$emit('select', 'ldapmain');
        findSubmitButton().vm.$emit('click');

        expect(wrapper.emitted('submit')).toHaveLength(1);
        expect(wrapper.emitted('submit')[0][0]).toEqual({ server: 'ldapmain' });
      });
    });
  });

  describe('server form group', () => {
    it('shows form group', () => {
      expect(findServerFormGroup().props()).toMatchObject({
        label: 'Server',
        state: true,
        invalidFeedback: 'This field is required',
      });
    });

    it('shows dropdown', () => {
      expect(findServerDropdown().attributes('class')).toBe('gl-max-w-30');
      expect(findServerDropdown().props()).toMatchObject({
        items: ldapServers,
        toggleText: 'Select server',
        selected: null,
        variant: 'default',
        category: 'secondary',
        block: true,
      });
    });

    describe('when a dropdown option is selected', () => {
      beforeEach(() => findServerDropdown().vm.$emit('select', 'ldapmain'));

      it('updates server value', () => {
        expect(findServerDropdown().props('selected')).toBe('ldapmain');
      });

      it('shows selected item in dropdown button', () => {
        // When toggleText is an empty string, the dropdown will use its default behavior of showing
        // the item.text.
        expect(findServerDropdown().props('toggleText')).toBe('');
      });
    });

    describe('when no server is selected and the form is submitted', () => {
      beforeEach(() => findSubmitButton().vm.$emit('click'));

      it('shows form group as invalid', () => {
        expect(findServerFormGroup().props('state')).toBe(false);
      });

      it('shows dropdown as invalid', () => {
        expect(findServerDropdown().props('variant')).toBe('danger');
      });

      describe('after a dropdown item is selected', () => {
        beforeEach(() => findServerDropdown().vm.$emit('select', 'ldapmain'));

        it('shows form group as valid', () => {
          expect(findServerFormGroup().props('state')).toBe(true);
        });

        it('shows dropdown as valid', () => {
          expect(findServerDropdown().props('variant')).toBe('default');
        });
      });
    });

    describe('when a server is selected and the form is submitted', () => {
      beforeEach(() => {
        findServerDropdown().vm.$emit('select', 'ldapmain');
        findSubmitButton().vm.$emit('click');
      });

      it('shows form group as valid', () => {
        expect(findServerFormGroup().props('state')).toBe(true);
      });

      it('shows dropdown as valid', () => {
        expect(findServerDropdown().props('variant')).toBe('default');
      });
    });
  });
});
