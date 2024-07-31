import StatusChecksForm from 'ee/projects/settings/branch_rules/components/view/status_checks/status_checks_form.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('Status checks in branch rules enterprise edition', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(StatusChecksForm);
  };

  const findSaveChangesButton = () => wrapper.findByTestId('save-btn');
  const findCancelButton = () => wrapper.findByTestId('cancel-btn');

  beforeEach(() => createComponent());

  describe('emits events to parent component', () => {
    it('emits saveChanges event when save button is clicked', () => {
      findSaveChangesButton().vm.$emit('click');
      expect(wrapper.emitted('saveChanges')).toEqual([[]]);
    });

    it('emits close event when cancel button is clicked', () => {
      findCancelButton().vm.$emit('click');
      expect(wrapper.emitted('close')).toEqual([[]]);
    });
  });
});
