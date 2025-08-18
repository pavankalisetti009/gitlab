import { GlFormFields } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogFlowForm from 'ee/ai/catalog/components/ai_catalog_flow_form.vue';
import AiCatalogStepsEditor from 'ee/ai/catalog/components/ai_catalog_steps_editor.vue';

describe('AiCatalogFlowForm', () => {
  let wrapper;

  const findErrorAlert = () => wrapper.findByTestId('flow-form-error-alert');
  const findFormFields = () => wrapper.findComponent(GlFormFields);
  const findProjectIdField = () => wrapper.findByTestId('flow-form-input-project-id');
  const findNameField = () => wrapper.findByTestId('flow-form-input-name');
  const findDescriptionField = () => wrapper.findByTestId('flow-form-textarea-description');
  const findSubmitButton = () => wrapper.findByTestId('flow-form-submit-button');
  const findStepsEditor = () => wrapper.findComponent(AiCatalogStepsEditor);

  const defaultProps = {
    mode: 'create',
    isLoading: false,
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
    it('does not render error alert', () => {
      createWrapper();

      expect(findErrorAlert().isVisible()).toBe(false);
    });

    it('renders the form with the correct initial values when props are provided', () => {
      createWrapper({ initialValues, mode: 'edit' });

      expect(findProjectIdField().props('value')).toBe(initialValues.projectId);
      expect(findNameField().props('value')).toBe(initialValues.name);
      expect(findDescriptionField().props('value')).toBe(initialValues.description);
    });

    it('renders the form with default values when no props are provided', () => {
      createWrapper();

      expect(findProjectIdField().props('value')).toBe('gid://gitlab/Project/1000000');
      expect(findNameField().props('value')).toBe('');
      expect(findDescriptionField().props('value')).toBe('');
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
      createWrapper({ initialValues, mode: 'edit' });

      await findFormFields().vm.$emit('submit');

      expect(wrapper.emitted('submit')).toEqual([[initialValues]]);
    });

    it('trims the form values before emitting them', async () => {
      const addRandomSpacesToString = (value) => `  ${value}  `;

      const formValuesWithRandomSpaces = {
        ...initialValues,
        projectId: addRandomSpacesToString(initialValues.projectId),
        name: addRandomSpacesToString(initialValues.name),
        description: addRandomSpacesToString(initialValues.description),
      };

      createWrapper({ initialValues: formValuesWithRandomSpaces });

      await findFormFields().vm.$emit('submit');

      expect(wrapper.emitted('submit')).toEqual([[initialValues]]);
    });
  });

  describe('with error message', () => {
    const mockErrorMessage = 'The flow could not be created';

    beforeEach(() => {
      createWrapper({ errorMessages: [mockErrorMessage] });
    });

    it('renders error alert', () => {
      expect(findErrorAlert().text()).toBe(mockErrorMessage);
    });

    it('renders error alert with list for multiple errors', () => {
      createWrapper({ errorMessages: ['error1', 'error2'] });

      expect(findErrorAlert().findAll('li')).toHaveLength(2);
    });

    it('emits dismiss-error event', () => {
      findErrorAlert().vm.$emit('dismiss');

      expect(wrapper.emitted('dismiss-error')).toHaveLength(1);
    });

    it('scrolls to error alert when errorMessages are set', async () => {
      const scrollIntoViewMock = jest.fn();
      const originalScrollIntoView = HTMLElement.prototype.scrollIntoView;
      HTMLElement.prototype.scrollIntoView = scrollIntoViewMock;
      createWrapper();

      await wrapper.setProps({ errorMessages: ['Error occurred'] });
      await nextTick();

      expect(scrollIntoViewMock).toHaveBeenCalledWith({
        behavior: 'smooth',
        block: 'center',
      });
      HTMLElement.prototype.scrollIntoView = originalScrollIntoView;
    });
  });
});
