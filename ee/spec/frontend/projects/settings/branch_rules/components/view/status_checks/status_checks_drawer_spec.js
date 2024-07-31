import StatusChecksDrawer from 'ee/projects/settings/branch_rules/components/view/status_checks/status_checks_drawer.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('Status checks in branch rules enterprise edition', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(StatusChecksDrawer);
  };

  const findStatusChecksForm = () => wrapper.findByTestId('status-checks-form');

  beforeEach(() => createComponent());

  describe('emits events to parent component', () => {
    it('emits saveChanges event', () => {
      findStatusChecksForm().vm.$emit('saveChanges');
      expect(wrapper.emitted('saveChanges')).toEqual([[]]);
    });

    it('emits close event', () => {
      findStatusChecksForm().vm.$emit('close');
      expect(wrapper.emitted('close')).toEqual([[]]);
    });
  });
});
