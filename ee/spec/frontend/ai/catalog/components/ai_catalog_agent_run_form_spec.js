import { GlForm, GlFormFields } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogAgentRunForm from 'ee/ai/catalog/components/ai_catalog_agent_run_form.vue';
import { mockAgent } from '../mock_data';

describe('AiCatalogAgentRunForm', () => {
  let wrapper;

  const defaultProps = {
    isSubmitting: false,
    aiCatalogAgent: mockAgent,
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findFormFields = () => wrapper.findComponent(GlFormFields);
  const findUserPromptField = () => wrapper.findByTestId('agent-run-form-user-prompt');
  const findSubmitButton = () => wrapper.findByTestId('agent-run-form-submit-button');

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(AiCatalogAgentRunForm, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlFormFields,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders form with submit button', () => {
    expect(findForm().exists()).toBe(true);
    expect(findSubmitButton().text()).toBe('Run');
  });

  it('renders form fields with correct initial values', () => {
    expect(findFormFields().props('fields')).toEqual({
      userPrompt: expect.any(Object),
    });
    expect(findFormFields().props('values').userPrompt).toBe(mockAgent.latestVersion.userPrompt);
  });

  describe('form submission', () => {
    it('emits form values on form submit', () => {
      const mockUserPrompt = 'Mock user prompt';

      findUserPromptField().vm.$emit('update', mockUserPrompt);
      findForm().vm.$emit('submit', {
        preventDefault: jest.fn(),
      });

      expect(wrapper.emitted('submit')[0]).toEqual([{ userPrompt: mockUserPrompt }]);
    });

    it('renders submit button as loading', async () => {
      createComponent();

      expect(findSubmitButton().props('loading')).toBe(false);

      await wrapper.setProps({ isSubmitting: true });

      expect(findSubmitButton().props('loading')).toBe(true);
    });
  });
});
