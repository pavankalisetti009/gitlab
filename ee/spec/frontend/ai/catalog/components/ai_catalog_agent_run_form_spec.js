import { nextTick } from 'vue';
import { GlForm, GlFormFields } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogAgentRunForm from 'ee/ai/catalog/components/ai_catalog_agent_run_form.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';

describe('AiCatalogAgentRunForm', () => {
  let wrapper;

  const defaultProps = {
    isSubmitting: false,
  };
  const routeParams = { id: 1 };

  const findForm = () => wrapper.findComponent(GlForm);
  const findFormFields = () => wrapper.findComponent(GlFormFields);
  const findClipboardButton = () => wrapper.findComponent(ClipboardButton);
  const findUserPromptField = () => wrapper.findByTestId('agent-run-form-user-prompt');

  const createComponent = ({ props = {}, stubs = { GlFormFields } } = {}) => {
    wrapper = shallowMountExtended(AiCatalogAgentRunForm, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      mocks: {
        $route: {
          params: routeParams,
        },
      },
      stubs,
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders form', () => {
    expect(findForm().exists()).toBe(true);
  });

  it('renders form fields with correct initial values', () => {
    expect(findFormFields().props('fields')).toEqual({
      userPrompt: expect.any(Object),
    });
    expect(findFormFields().props('values').userPrompt).toBe('');
  });

  it('renders clipboard button with correct values', async () => {
    createComponent({ stubs: {} });

    const mockUserPrompt = 'Mock user prompt';
    findFormFields().vm.$emit('input', { userPrompt: mockUserPrompt });
    await nextTick();

    expect(findClipboardButton().props('text')).toBe(mockUserPrompt);
  });

  describe('form submission', () => {
    it('emits form values on form submit', () => {
      const mockUserPrompt = 'Mock user prompt';

      findUserPromptField().vm.$emit('update', mockUserPrompt);
      findFormFields().vm.$emit('submit');

      expect(wrapper.emitted('submit')[0]).toEqual([{ userPrompt: mockUserPrompt }]);
    });

    it('trims the form values before emitting them', () => {
      const mockUserPrompt = 'Mock user prompt';

      findUserPromptField().vm.$emit('update', `  ${mockUserPrompt}  `);
      findFormFields().vm.$emit('submit');

      expect(wrapper.emitted('submit')[0]).toEqual([{ userPrompt: mockUserPrompt }]);
    });
  });
});
