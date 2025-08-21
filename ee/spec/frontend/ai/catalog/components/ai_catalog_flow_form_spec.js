import { GlFormFields } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogFlowForm from 'ee/ai/catalog/components/ai_catalog_flow_form.vue';
import AiCatalogStepsEditor from 'ee/ai/catalog/components/ai_catalog_steps_editor.vue';
import ErrorsAlert from 'ee/ai/catalog/components/errors_alert.vue';
import FormProjectDropdown from 'ee/ai/catalog/components/form_project_dropdown.vue';

describe('AiCatalogFlowForm', () => {
  let wrapper;

  const findErrorAlert = () => wrapper.findComponent(ErrorsAlert);
  const findFormFields = () => wrapper.findComponent(GlFormFields);
  const findProjectDropdown = () => wrapper.findComponent(FormProjectDropdown);
  const findNameField = () => wrapper.findByTestId('flow-form-input-name');
  const findDescriptionField = () => wrapper.findByTestId('flow-form-textarea-description');
  const findSubmitButton = () => wrapper.findByTestId('flow-form-submit-button');
  const findStepsEditor = () => wrapper.findComponent(AiCatalogStepsEditor);

  const defaultProps = {
    mode: 'create',
    isLoading: false,
    errorMessages: [],
  };

  const initialValues = {
    projectId: 'gid://gitlab/Project/1000000',
    name: 'My AI Flow',
    description: 'A helpful AI assistant',
    public: false,
    steps: [],
  };

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(AiCatalogFlowForm, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlFormFields,
      },
    });
  };

  describe('Initial Rendering', () => {
    it('renders the form with the correct initial values when props are provided', () => {
      createWrapper({ initialValues });

      expect(findProjectDropdown().props('value')).toBe(initialValues.projectId);
      expect(findNameField().props('value')).toBe(initialValues.name);
      expect(findDescriptionField().props('value')).toBe(initialValues.description);
    });

    it('renders the form with default values when no props are provided', () => {
      createWrapper();

      expect(findProjectDropdown().props('value')).toBe(null);
      expect(findNameField().props('value')).toBe('');
      expect(findDescriptionField().props('value')).toBe('');
    });

    it('does not render project dropdown when in edit mode', () => {
      createWrapper({ mode: 'edit' });

      expect(findProjectDropdown().exists()).toBe(false);
    });

    it('renders steps editor', () => {
      createWrapper();

      expect(findStepsEditor().exists()).toBe(true);
    });
  });

  describe('Loading Prop', () => {
    it('shows button with loading icon when the loading property is true', () => {
      createWrapper({ isLoading: true });

      expect(findSubmitButton().props('loading')).toBe(true);
    });

    it('does not show the button with loading icon when the loading property is false', () => {
      createWrapper({ isLoading: false });

      expect(findSubmitButton().props('loading')).toBe(false);
    });
  });

  describe('Form Submission', () => {
    it('emits form values when user clicks submit', async () => {
      createWrapper({ initialValues });

      await findFormFields().vm.$emit('submit');

      expect(wrapper.emitted('submit')).toEqual([[initialValues]]);
    });

    it('trims the form values before emitting them', async () => {
      const addRandomSpacesToString = (value) => `  ${value}  `;

      const formValuesWithRandomSpaces = {
        ...initialValues,
        name: addRandomSpacesToString(initialValues.name),
        description: addRandomSpacesToString(initialValues.description),
      };

      createWrapper({ initialValues: formValuesWithRandomSpaces });

      await findFormFields().vm.$emit('submit');

      expect(wrapper.emitted('submit')).toEqual([[initialValues]]);
    });
  });

  describe('with error messages', () => {
    const mockErrorMessage = 'The flow could not be created';

    beforeEach(() => {
      createWrapper({ errorMessages: [mockErrorMessage] });
    });

    it('passes error alert', () => {
      expect(findErrorAlert().props('errorMessages')).toEqual([mockErrorMessage]);
    });

    it('renders errors with form errors', async () => {
      const formError = 'Project is required';

      await findProjectDropdown().vm.$emit('error', formError);

      expect(findErrorAlert().props('errorMessages')).toEqual([mockErrorMessage, formError]);
    });

    it('emits dismiss-errors event', () => {
      findErrorAlert().vm.$emit('dismiss');

      expect(wrapper.emitted('dismiss-errors')).toHaveLength(1);
    });
  });
});
