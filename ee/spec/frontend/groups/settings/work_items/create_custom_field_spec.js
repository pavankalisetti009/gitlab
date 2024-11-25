import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CreateCustomField from 'ee/groups/settings/work_items/create_custom_field.vue';
import createCustomFieldMutation from 'ee/groups/settings/work_items/create_custom_field.mutation.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('CreateCustomField', () => {
  let wrapper;

  const findToggleModalButton = () => wrapper.findByTestId('toggle-modal');
  const findModal = () => wrapper.findComponent(GlModal);
  const findFieldTypeSelect = () => wrapper.find('#field-type');
  const findFieldNameFormGroup = () => wrapper.find('[label-for="field-name"]');
  const findFieldNameInput = () => wrapper.find('#field-name');

  const findCustomFieldOptionsFormGroup = () =>
    wrapper.find('[data-testid="custom-field-options"]');
  const findAddSelectOptionButton = () => wrapper.findByTestId('add-select-option');
  const findAddSelectInputAt = (i) => wrapper.findByTestId(`select-options-${i}`);

  const findRemoveSelectButtonAt = (i) => wrapper.findByTestId(`remove-select-option-${i}`);

  const findSaveCustomFieldButton = () => wrapper.findByTestId('save-custom-field');

  const mockCreateFieldResponse = {
    data: {
      customFieldCreate: {
        customField: {
          id: 'gid://gitlab/Issuables::CustomField/13',
        },
        errors: [],
      },
    },
  };

  const fullPath = 'group/subgroup';

  const createComponent = ({
    props = {},
    createFieldResponse = {},
    createFieldHandler = jest.fn().mockResolvedValue(createFieldResponse),
  } = {}) => {
    wrapper = shallowMountExtended(CreateCustomField, {
      propsData: {
        ...props,
      },
      provide: {
        fullPath,
      },
      apolloProvider: createMockApollo([[createCustomFieldMutation, createFieldHandler]]),
      stubs: {
        GlModal,
      },
    });
  };

  describe('initial rendering', () => {
    it('renders create field button', () => {
      createComponent();
      expect(findToggleModalButton().text()).toBe('Create field');
    });

    it('modal is hidden by default', () => {
      createComponent();
      expect(findModal().props('visible')).toBe(false);
    });
  });

  describe('modal visibility', () => {
    it('shows modal when create button is clicked', async () => {
      createComponent();
      await findToggleModalButton().vm.$emit('click');
      await nextTick();
      expect(findModal().props('visible')).toBe(true);
    });

    it('hides modal when hide event is emitted', async () => {
      createComponent();
      await findToggleModalButton().vm.$emit('click');
      await findModal().vm.$emit('hide');
      expect(findModal().props('visible')).toBe(false);
    });
  });

  describe('form behavior', () => {
    beforeEach(() => {
      createComponent();
      findToggleModalButton().vm.$emit('click');
    });

    it.each(['SINGLE_SELECT', 'MULTI_SELECT'])(
      `shows select options section when field type is %s`,
      async (type) => {
        await findFieldTypeSelect().vm.$emit('input', type);
        await nextTick();

        expect(findAddSelectOptionButton().exists()).toBe(true);
        expect(findAddSelectInputAt(0).exists()).toBe(true);
      },
    );

    it.each(['NUMBER', 'TEXT'])(
      `hides select options section when field type is %s`,
      async (type) => {
        await findFieldTypeSelect().vm.$emit('input', type);
        await nextTick();

        expect(findAddSelectOptionButton().exists()).toBe(false);
        expect(findAddSelectInputAt(0).exists()).toBe(false);
      },
    );

    it('adds select option when add button is clicked', async () => {
      await findFieldTypeSelect().vm.$emit('input', 'SINGLE_SELECT');
      await nextTick();

      expect(findAddSelectOptionButton().exists()).toBe(true);
      expect(findAddSelectInputAt(1).exists()).toBe(false);

      findAddSelectOptionButton().vm.$emit('click');
      await nextTick();

      expect(findAddSelectInputAt(1).exists()).toBe(true);
    });

    it('remove button removes select option', async () => {
      await findFieldTypeSelect().vm.$emit('input', 'SINGLE_SELECT');
      await nextTick();

      findRemoveSelectButtonAt(0).vm.$emit('click');
      await nextTick();

      expect(findAddSelectInputAt(0).exists()).toBe(false);
    });
  });

  describe('saveCustomField', () => {
    it('calls mutation with correct variables', async () => {
      const createFieldHandler = jest.fn().mockResolvedValue(mockCreateFieldResponse);
      createComponent({ createFieldHandler });

      await findToggleModalButton().vm.$emit('click');

      // set field inputs
      await findFieldTypeSelect().vm.$emit('input', 'TEXT');
      await findFieldNameInput().vm.$emit('input', 'Test Field');

      await nextTick();

      findSaveCustomFieldButton().vm.$emit('click');

      await waitForPromises();

      expect(Sentry.captureException).not.toHaveBeenCalled();

      expect(createFieldHandler).toHaveBeenCalledWith({
        groupPath: fullPath,
        name: 'Test Field',
        fieldType: 'TEXT',
        selectOptions: undefined,
      });
    });

    it('shows validation error if field name is empty', async () => {
      createComponent({ createFieldResponse: mockCreateFieldResponse });
      await findToggleModalButton().vm.$emit('click');

      await nextTick();

      expect(findFieldNameFormGroup().attributes('invalid-feedback')).toBe('Name is required.');
    });

    it('shows validation error if no select options added', async () => {
      createComponent({ createFieldResponse: mockCreateFieldResponse });
      await findToggleModalButton().vm.$emit('click');

      await findFieldTypeSelect().vm.$emit('input', 'SINGLE_SELECT');

      await nextTick();

      expect(findCustomFieldOptionsFormGroup().attributes('invalid-feedback')).toBe(
        'At least one option is required.',
      );
    });

    it('handles mutation errors', async () => {
      const errorMessage = 'Error creating custom field';
      const errorResponse = {
        data: {
          customFieldCreate: {
            customField: null,
            errors: [errorMessage],
          },
        },
      };
      createComponent({ createFieldResponse: errorResponse });
      await findToggleModalButton().vm.$emit('click');

      // set field inputs
      await findFieldTypeSelect().vm.$emit('input', 'TEXT');
      await findFieldNameInput().vm.$emit('input', 'Test Field');

      findSaveCustomFieldButton().vm.$emit('click');

      await waitForPromises();

      expect(Sentry.captureException).toHaveBeenCalled();
    });
  });
});
