import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';

import { GlFormFields, GlFormRadioGroup } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { VISIBILITY_LEVEL_PRIVATE, VISIBILITY_LEVEL_PUBLIC } from 'ee/ai/catalog/constants';
import AiCatalogAgentForm from 'ee/ai/catalog/components/ai_catalog_agent_form.vue';
import aiCatalogBuiltInToolsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_built_in_tools.query.graphql';
import ErrorsAlert from 'ee/ai/catalog/components/errors_alert.vue';
import FormProjectDropdown from 'ee/ai/catalog/components/form_project_dropdown.vue';

import { mockToolQueryResponse, toolTitles } from '../mock_data';

Vue.use(VueApollo);

describe('AiCatalogAgentForm', () => {
  let wrapper;
  let mockApollo;

  const findErrorAlert = () => wrapper.findComponent(ErrorsAlert);
  const findFormFields = () => wrapper.findComponent(GlFormFields);
  const findProjectDropdown = () => wrapper.findComponent(FormProjectDropdown);
  const findNameField = () => wrapper.findByTestId('agent-form-input-name');
  const findDescriptionField = () => wrapper.findByTestId('agent-form-textarea-description');
  const findSystemPromptField = () => wrapper.findByTestId('agent-form-textarea-system-prompt');
  const findToolsField = () => wrapper.findByTestId('agent-form-token-selector-tools');
  const findToolOptions = () =>
    findToolsField()
      .props('dropdownItems')
      .map((t) => t.name)
      .join(', ');
  const findUserPromptField = () => wrapper.findByTestId('agent-form-textarea-user-prompt');
  const findVisibilityLevel = () => wrapper.findByTestId('agent-form-radio-group-visibility-level');
  const findVisibilityLevelAlert = () => wrapper.findByTestId('agent-form-visibility-level-alert');
  const findFormRadioGroup = () => findVisibilityLevel().findComponent(GlFormRadioGroup);
  const findSubmitButton = () => wrapper.findByTestId('agent-form-submit-button');

  const defaultProps = {
    mode: 'create',
    isLoading: false,
    errorMessages: [],
  };

  const initialValues = {
    projectId: 'gid://gitlab/Project/1000000',
    name: 'My AI Agent',
    description: 'A helpful AI assistant',
    systemPrompt: 'You are a helpful assistant',
    userPrompt: 'Help me with coding',
    public: true,
    tools: [],
  };

  const mockToolQueryHandler = jest.fn().mockResolvedValue(mockToolQueryResponse);

  const createWrapper = (props = {}) => {
    mockApollo = createMockApollo([[aiCatalogBuiltInToolsQuery, mockToolQueryHandler]]);

    wrapper = shallowMountExtended(AiCatalogAgentForm, {
      apolloProvider: mockApollo,
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
      expect(findSystemPromptField().props('value')).toBe(initialValues.systemPrompt);
      expect(findUserPromptField().props('value')).toBe(initialValues.userPrompt);
      expect(findVisibilityLevel().attributes('checked')).toBe(String(VISIBILITY_LEVEL_PUBLIC));
    });

    it('renders the form with default values when no props are provided', () => {
      createWrapper();

      expect(findProjectDropdown().props('value')).toBe(null);
      expect(findNameField().props('value')).toBe('');
      expect(findDescriptionField().props('value')).toBe('');
      expect(findSystemPromptField().props('value')).toBe('');
      expect(findUserPromptField().props('value')).toBe('');
      expect(findVisibilityLevel().attributes('checked')).toBe(String(VISIBILITY_LEVEL_PRIVATE));
    });

    it('does not render project dropdown when in edit mode', () => {
      createWrapper({ mode: 'edit' });

      expect(findProjectDropdown().exists()).toBe(false);
    });
  });

  describe('Visibility Level', () => {
    describe.each`
      selectedVisibility | expectedAlertText
      ${'private'}       | ${false}
      ${'public'}        | ${'A public agent can be made private only if it is not used.'}
    `(
      'when creating an agent and "$selectedVisibility" visibility is selected',
      ({ selectedVisibility, expectedAlertText }) => {
        beforeEach(() => {
          createWrapper();
          const visibilityLevel =
            selectedVisibility === 'public' ? VISIBILITY_LEVEL_PUBLIC : VISIBILITY_LEVEL_PRIVATE;
          findFormRadioGroup().vm.$emit('input', visibilityLevel);
        });

        it(`${expectedAlertText ? 'renders' : 'does not render'} visibility alert`, () => {
          expect(findVisibilityLevelAlert().exists()).toBe(Boolean(expectedAlertText));
          if (expectedAlertText) {
            expect(findVisibilityLevelAlert().text()).toBe(expectedAlertText);
          }
        });
      },
    );

    describe.each`
      initialVisibility | selectedVisibility | expectedAlertText
      ${'private'}      | ${'private'}       | ${false}
      ${'private'}      | ${'public'}        | ${'A public agent can be made private only if it is not used.'}
      ${'public'}       | ${'private'}       | ${'This agent can be made private if it is not used.'}
      ${'public'}       | ${'public'}        | ${false}
    `(
      'when editing a $initialVisibility agent and "$selectedVisibility" visibility is selected',
      ({ initialVisibility, selectedVisibility, expectedAlertText }) => {
        beforeEach(() => {
          createWrapper({
            mode: 'edit',
            initialValues: {
              ...initialValues,
              public: initialVisibility === 'public',
            },
          });
          const visibilityLevel =
            selectedVisibility === 'public' ? VISIBILITY_LEVEL_PUBLIC : VISIBILITY_LEVEL_PRIVATE;
          findFormRadioGroup().vm.$emit('input', visibilityLevel);
        });

        it(`${expectedAlertText ? 'renders' : 'does not render'} visibility alert`, () => {
          expect(findVisibilityLevelAlert().exists()).toBe(Boolean(expectedAlertText));
          if (expectedAlertText) {
            expect(findVisibilityLevelAlert().text()).toBe(expectedAlertText);
          }
        });
      },
    );
  });

  describe('Tool selection', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('fetches list data', () => {
      expect(mockToolQueryHandler).toHaveBeenCalled();
    });

    it('lists all available tools', () => {
      expect(findToolOptions()).toStrictEqual(toolTitles.join(', '));
    });

    it('filters available tools based on the search query', async () => {
      findToolsField().vm.$emit('text-input', 'blob');
      await nextTick();

      expect(findToolOptions()).toStrictEqual('Gitlab Blob Search');
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
        systemPrompt: addRandomSpacesToString(initialValues.systemPrompt),
        userPrompt: addRandomSpacesToString(initialValues.userPrompt),
      };

      createWrapper({ initialValues: formValuesWithRandomSpaces });

      await findFormFields().vm.$emit('submit');

      expect(wrapper.emitted('submit')).toEqual([[initialValues]]);
    });
  });

  describe('with error messages', () => {
    const mockErrorMessage = 'The agent could not be created';

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
