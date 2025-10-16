import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import { GlForm } from '@gitlab/ui';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import AiCatalogAgentForm from 'ee/ai/catalog/components/ai_catalog_agent_form.vue';
import aiCatalogBuiltInToolsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_built_in_tools.query.graphql';
import FormProjectDropdown from 'ee/ai/catalog/components/form_project_dropdown.vue';
import FormGroup from 'ee/ai/catalog/components/form_group.vue';
import VisibilityLevelRadioGroup from 'ee/ai/catalog/components//visibility_level_radio_group.vue';
import { VISIBILITY_LEVEL_PRIVATE, VISIBILITY_LEVEL_PUBLIC } from 'ee/ai/catalog/constants';
import { mockToolsIds, mockToolsQueryResponse } from '../mock_data';

Vue.use(VueApollo);

describe('AiCatalogAgentForm', () => {
  let wrapper;
  let mockApollo;

  const findErrorAlert = () => wrapper.findComponent(ErrorsAlert);
  const findForm = () => wrapper.findComponent(GlForm);
  const findProjectDropdown = () => wrapper.findComponent(FormProjectDropdown);
  const findVisibilityLevelRadioGroup = () => wrapper.findComponent(VisibilityLevelRadioGroup);
  const findNameField = () => wrapper.findByTestId('agent-form-input-name');
  const findDescriptionField = () => wrapper.findByTestId('agent-form-textarea-description');
  const findSystemPromptField = () => wrapper.findByTestId('agent-form-textarea-system-prompt');
  const findToolsField = () => wrapper.findByTestId('agent-form-token-selector-tools');
  const findToolsOptions = () =>
    findToolsField()
      .props('dropdownItems')
      .map((t) => t.name);
  const findSubmitButton = () => wrapper.findByTestId('agent-form-submit-button');

  const defaultProps = {
    mode: 'create',
    isLoading: false,
    errors: [],
  };
  const routeParams = { id: 1 };
  const initialValues = {
    projectId: 'gid://gitlab/Project/1000000',
    name: 'My AI Agent',
    description: 'A helpful AI assistant',
    systemPrompt: 'You are a helpful assistant',
    public: true,
    tools: [],
  };

  const mockToolsQueryHandler = jest.fn().mockResolvedValue(mockToolsQueryResponse);

  const createWrapper = ({ props = {}, projectId = '1000000', isGlobal = false } = {}) => {
    mockApollo = createMockApollo([[aiCatalogBuiltInToolsQuery, mockToolsQueryHandler]]);

    wrapper = shallowMountExtended(AiCatalogAgentForm, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        projectId,
        isGlobal,
      },
      mocks: {
        $route: {
          params: props.mode === 'create' ? {} : routeParams,
        },
      },
      stubs: {
        FormGroup,
        GlForm,
      },
    });
  };

  describe('Initial Rendering', () => {
    it('renders the form with the correct initial values when props are provided', () => {
      createWrapper({ props: { initialValues } });

      expect(findProjectDropdown().props('value')).toBe(initialValues.projectId);
      expect(findNameField().props('value')).toBe(initialValues.name);
      expect(findDescriptionField().props('value')).toBe(initialValues.description);
      expect(findSystemPromptField().props('value')).toBe(initialValues.systemPrompt);
      expect(findVisibilityLevelRadioGroup().props('initialValue')).toBe(initialValues.public);
      expect(findVisibilityLevelRadioGroup().props('value')).toBe(VISIBILITY_LEVEL_PUBLIC);
    });

    it('renders the form with default values when no props are provided and form is global', () => {
      createWrapper({ isGlobal: true });

      expect(findProjectDropdown().props('value')).toBe(null);
      expect(findNameField().props('value')).toBe('');
      expect(findDescriptionField().props('value')).toBe('');
      expect(findSystemPromptField().props('value')).toBe('');
      expect(findVisibilityLevelRadioGroup().props('initialValue')).toBe(false);
      expect(findVisibilityLevelRadioGroup().props('value')).toBe(VISIBILITY_LEVEL_PRIVATE);
    });

    it('renders the form with default values and provided project when no props are provided and form is not global', () => {
      createWrapper({ isGlobal: false });

      expect(findProjectDropdown().props('value')).toBe('gid://gitlab/Project/1000000');
      expect(findNameField().props('value')).toBe('');
      expect(findDescriptionField().props('value')).toBe('');
      expect(findSystemPromptField().props('value')).toBe('');
      expect(findVisibilityLevelRadioGroup().props('initialValue')).toBe(false);
      expect(findVisibilityLevelRadioGroup().props('value')).toBe(VISIBILITY_LEVEL_PRIVATE);
    });

    it('renders project dropdown as disabled when in edit mode', () => {
      createWrapper({ props: { mode: 'edit' } });

      expect(findProjectDropdown().props('disabled')).toBe(true);
    });
  });

  describe('Tools selection', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('renders tools selector and fetches list data', () => {
      expect(findToolsField().props('selectedTokens')).toEqual([]);
      expect(mockToolsQueryHandler).toHaveBeenCalled();
    });

    it('lists all available tools', () => {
      expect(findToolsOptions()).toStrictEqual([
        'Ci Linter',
        'Gitlab Blob Search',
        'Run Git Command',
      ]);
    });

    it('filters available tools based on the search query', async () => {
      findToolsField().vm.$emit('text-input', 'git');
      await nextTick();

      expect(findToolsOptions()).toStrictEqual(['Gitlab Blob Search', 'Run Git Command']);
    });

    describe('when initialValues has tools', () => {
      beforeEach(async () => {
        createWrapper({
          props: {
            initialValues: {
              ...initialValues,
              tools: mockToolsIds,
            },
          },
        });
        await waitForPromises();
      });

      it('renders tools selector with sorted pre-selected tools', () => {
        const selectedTools = findToolsField()
          .props('selectedTokens')
          .map((t) => t.name);
        expect(selectedTools).toStrictEqual(['Ci Linter', 'Gitlab Blob Search', 'Run Git Command']);
      });
    });
  });

  describe('Loading Prop', () => {
    it('shows button with loading icon when the loading property is true', () => {
      createWrapper({ props: { isLoading: true } });

      expect(findSubmitButton().props('loading')).toBe(true);
    });

    it('does not show the button with loading icon when the loading property is false', () => {
      createWrapper({ props: { isLoading: false } });

      expect(findSubmitButton().props('loading')).toBe(false);
    });
  });

  describe('Form Submission', () => {
    it('emits form values when user clicks submit', async () => {
      createWrapper({ props: { initialValues } });

      await findForm().vm.$emit('submit', {
        preventDefault: jest.fn(),
      });

      expect(wrapper.emitted('submit')).toEqual([[initialValues]]);
    });

    it('trims the form values before emitting them', async () => {
      const addRandomSpacesToString = (value) => `  ${value}  `;

      const formValuesWithRandomSpaces = {
        ...initialValues,
        name: addRandomSpacesToString(initialValues.name),
        description: addRandomSpacesToString(initialValues.description),
        systemPrompt: addRandomSpacesToString(initialValues.systemPrompt),
      };

      createWrapper({ props: { initialValues: formValuesWithRandomSpaces } });

      await findForm().vm.$emit('submit', {
        preventDefault: jest.fn(),
      });

      expect(wrapper.emitted('submit')).toEqual([[initialValues]]);
    });
  });

  describe('with error messages', () => {
    const mockErrorMessage = 'The agent could not be created';

    beforeEach(() => {
      createWrapper({ props: { errors: [mockErrorMessage] } });
    });

    it('passes error alert', () => {
      expect(findErrorAlert().props('errors')).toEqual([mockErrorMessage]);
    });

    it('renders errors with form errors', async () => {
      const formError = 'Project is required';

      await findProjectDropdown().vm.$emit('error', formError);

      expect(findErrorAlert().props('errors')).toEqual([mockErrorMessage, formError]);
    });

    it('emits dismiss-errors event', () => {
      findErrorAlert().vm.$emit('dismiss');

      expect(wrapper.emitted('dismiss-errors')).toHaveLength(1);
    });
  });
});
