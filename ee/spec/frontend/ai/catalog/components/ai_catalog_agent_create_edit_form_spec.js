import { GlFormFields } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogAgentCreateEditForm from 'ee/ai/catalog/components/ai_catalog_agent_create_edit_form.vue';
import {
  MAX_LENGTH_NAME,
  MAX_LENGTH_DESCRIPTION,
  MAX_LENGTH_PROMPT,
} from 'ee/ai/catalog/constants';

describe('AiCatalogAgentForm', () => {
  let wrapper;

  const findFormFields = () => wrapper.findComponent(GlFormFields);
  const findNameField = () => wrapper.findByTestId('agent-form-input-name');
  const findDescriptionField = () => wrapper.findByTestId('agent-form-textarea-description');
  const findSystemPromptField = () => wrapper.findByTestId('agent-form-textarea-system-prompt');
  const findUserPromptField = () => wrapper.findByTestId('agent-form-textarea-user-prompt');
  const findSubmitButton = () => wrapper.findByTestId('agent-form-submit-button');

  const defaultProps = {
    mode: 'create',
    isLoading: false,
  };

  const defaultFormValues = {
    name: 'My AI Agent',
    description: 'A helpful AI assistant',
    systemPrompt: 'You are a helpful assistant',
    userPrompt: 'Help me with coding',
  };

  const createWrapper = (props = {}) => {
    wrapper = mountExtended(AiCatalogAgentCreateEditForm, {
      attachTo: document.body,
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  describe('Initial Rendering', () => {
    it('renders the form with the correct initial values when props are provided', () => {
      const initialProps = {
        ...defaultFormValues,
        mode: 'edit',
      };

      createWrapper(initialProps);

      expect(findNameField().element.value).toBe(defaultFormValues.name);
      expect(findDescriptionField().element.value).toBe(defaultFormValues.description);
      expect(findSystemPromptField().element.value).toBe(defaultFormValues.systemPrompt);
      expect(findUserPromptField().element.value).toBe(defaultFormValues.userPrompt);
    });

    it('renders the form with empty values when no props are provided', () => {
      createWrapper();

      expect(findNameField().element.value).toBe('');
      expect(findDescriptionField().element.value).toBe('');
      expect(findSystemPromptField().element.value).toBe('');
      expect(findUserPromptField().element.value).toBe('');
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
      const initialProps = {
        ...defaultFormValues,
        mode: 'edit',
      };

      createWrapper(initialProps);

      await findFormFields().vm.$emit('submit');

      expect(wrapper.emitted('submit')).toEqual([[defaultFormValues]]);
    });

    it('trims the form values before emitting them', async () => {
      createWrapper();

      const addRandomSpacesToString = (value) => `  ${value}  `;

      const formValuesWithRandomSpaces = {
        name: addRandomSpacesToString(defaultFormValues.name),
        description: addRandomSpacesToString(defaultFormValues.description),
        systemPrompt: addRandomSpacesToString(defaultFormValues.systemPrompt),
        userPrompt: addRandomSpacesToString(defaultFormValues.userPrompt),
      };

      await findNameField().setValue(formValuesWithRandomSpaces.name);
      await findDescriptionField().setValue(formValuesWithRandomSpaces.description);
      await findSystemPromptField().setValue(formValuesWithRandomSpaces.systemPrompt);
      await findUserPromptField().setValue(formValuesWithRandomSpaces.userPrompt);
      await findFormFields().vm.$emit('submit');

      expect(wrapper.emitted('submit')).toEqual([[defaultFormValues]]);
    });
  });

  describe('Validation', () => {
    it('enforces character limit on name field', async () => {
      createWrapper();

      const longText = 'a'.repeat(MAX_LENGTH_NAME + 1);
      await findNameField().setValue(longText);
      await findNameField().trigger('blur');

      const errorMessage = wrapper.find('[data-testid="agent-form-input-name"] + div');

      expect(errorMessage.text()).toBe(
        `Input cannot exceed ${MAX_LENGTH_NAME} characters. Please shorten your input.`,
      );
    });

    it('enforces character limit on description field', async () => {
      createWrapper();

      const longText = 'a'.repeat(MAX_LENGTH_DESCRIPTION + 1);
      await findDescriptionField().setValue(longText);
      await findDescriptionField().trigger('blur');

      const errorMessage = wrapper.find('[data-testid="agent-form-textarea-description"] + div');

      expect(errorMessage.text()).toBe(
        `Input cannot exceed ${MAX_LENGTH_DESCRIPTION} characters. Please shorten your input.`,
      );
    });

    it('enforces character limit on system prompt field', async () => {
      createWrapper();

      const longText = 'a'.repeat(MAX_LENGTH_PROMPT + 1);
      await findSystemPromptField().setValue(longText);
      await findSystemPromptField().trigger('blur');

      const errorMessage = wrapper.find('[data-testid="agent-form-textarea-system-prompt"] + div');

      expect(errorMessage.text()).toBe(
        `Input cannot exceed ${MAX_LENGTH_PROMPT} characters. Please shorten your input.`,
      );
    });

    it('enforces character limit on user prompt field', async () => {
      createWrapper();

      const longText = 'a'.repeat(MAX_LENGTH_PROMPT + 1);
      await findUserPromptField().setValue(longText);
      await findUserPromptField().trigger('blur');

      const errorMessage = wrapper.find('[data-testid="agent-form-textarea-user-prompt"] + div');

      expect(errorMessage.text()).toBe(
        `Input cannot exceed ${MAX_LENGTH_PROMPT} characters. Please shorten your input.`,
      );
    });
  });
});
