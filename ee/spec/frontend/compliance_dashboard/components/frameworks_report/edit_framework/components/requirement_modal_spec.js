import { GlModal, GlFormInput, GlFormTextarea } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RequirementModal from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/requirement_modal.vue';
import { emptyRequirement } from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/constants';
import waitForPromises from 'helpers/wait_for_promises';

describe('RequirementModal', () => {
  let wrapper;

  const defaultProps = {
    requirement: {
      ...emptyRequirement,
    },
  };
  const mockEvent = {
    preventDefault: jest.fn(),
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findNameInput = () => wrapper.findComponent(GlFormInput);
  const findNameInputGroup = () => wrapper.findByTestId('name-input-group');
  const findDescriptionTextarea = () => wrapper.findComponent(GlFormTextarea);
  const findDescriptionInputGroup = () => wrapper.findByTestId('description-input-group');
  const submitModalForm = () => findModal().vm.$emit('primary', mockEvent);

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(RequirementModal, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };
  describe('Rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the modal', () => {
      expect(findModal().exists()).toBe(true);
    });

    it('renders the name input field', () => {
      expect(findNameInput().exists()).toBe(true);
    });

    it('renders the description textarea', () => {
      expect(findDescriptionTextarea().exists()).toBe(true);
    });

    it('renders the correct title for a new requirement', () => {
      expect(findModal().attributes('title')).toBe('Create new requirement');
    });
  });
  describe('Validation', () => {
    beforeEach(() => {
      createComponent();
    });

    it('validates that name is required', async () => {
      submitModalForm();
      await waitForPromises();
      expect(findNameInputGroup().attributes('state')).toBe(undefined);
    });

    it('validates that description is required', async () => {
      submitModalForm();
      await waitForPromises();
      expect(findDescriptionInputGroup().attributes('state')).toBe(undefined);
    });

    it('validates that the form is valid when fields are filled', async () => {
      const name = 'Test Name';
      const description = 'Test Description';
      findNameInput().vm.$emit('input', name);
      findDescriptionTextarea().vm.$emit('input', description);
      submitModalForm();
      await waitForPromises();
      expect(findNameInputGroup().attributes('state')).toBe('true');
      expect(findDescriptionInputGroup().attributes('state')).toBe('true');
    });

    it('emits save event with requirement data', async () => {
      const name = 'Test Name';
      const description = 'Test Description';
      findNameInput().vm.$emit('input', name);
      findDescriptionTextarea().vm.$emit('input', description);
      submitModalForm();
      await waitForPromises();
      expect(wrapper.emitted('save')).toEqual([
        [
          {
            description,
            name,
          },
        ],
      ]);
    });
  });
});
