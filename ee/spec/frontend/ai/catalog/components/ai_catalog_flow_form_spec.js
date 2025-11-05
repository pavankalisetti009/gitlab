import { GlForm } from '@gitlab/ui';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogFlowForm from 'ee/ai/catalog/components/ai_catalog_flow_form.vue';
import FormFlowType from 'ee/ai/catalog/components/form_flow_type.vue';
import FormProjectDropdown from 'ee/ai/catalog/components/form_project_dropdown.vue';
import VisibilityLevelRadioGroup from 'ee/ai/catalog/components//visibility_level_radio_group.vue';
import FormGroup from 'ee/ai/catalog/components/form_group.vue';
import { VISIBILITY_LEVEL_PRIVATE, VISIBILITY_LEVEL_PUBLIC } from 'ee/ai/catalog/constants';

describe('AiCatalogFlowForm', () => {
  let wrapper;

  const findErrorAlert = () => wrapper.findComponent(ErrorsAlert);
  const findForm = () => wrapper.findComponent(GlForm);
  const findFlowType = () => wrapper.findComponent(FormFlowType);
  const findProjectDropdown = () => wrapper.findComponent(FormProjectDropdown);
  const findVisibilityLevelRadioGroup = () => wrapper.findComponent(VisibilityLevelRadioGroup);
  const findNameField = () => wrapper.findByTestId('flow-form-input-name');
  const findDescriptionField = () => wrapper.findByTestId('flow-form-textarea-description');
  const findSubmitButton = () => wrapper.findByTestId('flow-form-submit-button');
  const findDefinitionFlowField = () => wrapper.findByTestId('flow-form-definition-flow');
  const findDefinitionThirdPartyFlowField = () =>
    wrapper.findByTestId('flow-form-definition-third-party-flow');

  const submitForm = async () => {
    await findForm().vm.$emit('submit', {
      preventDefault: jest.fn(),
    });
  };

  const defaultProps = {
    mode: 'create',
    isLoading: false,
    errors: [],
  };
  const routeParams = { id: 1 };
  const initialValues = {
    projectId: 'gid://gitlab/Project/1000000',
    type: 'FLOW',
    name: 'My AI Flow',
    description: 'A helpful AI assistant',
    public: true,
    release: true,
    definition: 'version: "v1"',
  };

  const createWrapper = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(AiCatalogFlowForm, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        projectId: '2000000',
        isGlobal: true,
        glFeatures: {
          aiCatalogFlows: true,
          aiCatalogThirdPartyFlows: true,
        },
        ...provide,
      },
      mocks: {
        $route: {
          params: props.mode === 'create' ? {} : routeParams,
        },
      },
      stubs: {
        GlForm,
        FormGroup,
      },
    });
  };

  describe('Initial Rendering', () => {
    it('renders the form with the correct initial values when props are provided', () => {
      createWrapper({ props: { initialValues } });

      expect(findProjectDropdown().props('value')).toBe(initialValues.projectId);
      expect(findFlowType().props('value')).toBe('FLOW');
      expect(findNameField().props('value')).toBe(initialValues.name);
      expect(findDescriptionField().props('value')).toBe(initialValues.description);
      expect(findVisibilityLevelRadioGroup().props('initialValue')).toBe(initialValues.public);
      expect(findVisibilityLevelRadioGroup().props('value')).toBe(VISIBILITY_LEVEL_PUBLIC);
      expect(findDefinitionFlowField().props('value')).toBe(initialValues.definition);
      expect(findDefinitionThirdPartyFlowField().exists()).toBe(false);
    });

    it('renders the form with default values when no props are provided and form is not global', () => {
      createWrapper({ provide: { isGlobal: false } });

      expect(findProjectDropdown().props('value')).toBe('gid://gitlab/Project/2000000');
      expect(findFlowType().props('value')).toBe('FLOW');
      expect(findNameField().props('value')).toBe('');
      expect(findDescriptionField().props('value')).toBe('');
      expect(findVisibilityLevelRadioGroup().props('initialValue')).toBe(false);
      expect(findVisibilityLevelRadioGroup().props('value')).toBe(VISIBILITY_LEVEL_PRIVATE);
      expect(findDefinitionFlowField().props('value')).toBe('');
      expect(findDefinitionThirdPartyFlowField().exists()).toBe(false);
    });

    it('renders the form with default values when no props are provided and form is global', () => {
      createWrapper();

      expect(findProjectDropdown().props('value')).toBe(null);
      expect(findFlowType().props('value')).toBe('FLOW');
      expect(findNameField().props('value')).toBe('');
      expect(findDescriptionField().props('value')).toBe('');
      expect(findVisibilityLevelRadioGroup().props('initialValue')).toBe(false);
      expect(findVisibilityLevelRadioGroup().props('value')).toBe(VISIBILITY_LEVEL_PRIVATE);
      expect(findDefinitionFlowField().props('value')).toBe('');
      expect(findDefinitionThirdPartyFlowField().exists()).toBe(false);
    });

    describe('when in edit mode', () => {
      beforeEach(() => {
        createWrapper({ props: { mode: 'edit' } });
      });

      it('renders project dropdown as disabled when in edit mode', () => {
        expect(findProjectDropdown().props('disabled')).toBe(true);
      });

      it('renders flow type as disabled', () => {
        expect(findFlowType().props('disabled')).toBe(true);
      });
    });
  });

  describe('Definition Field', () => {
    describe('when flow type is FLOW', () => {
      it('initializes definitionFlow with definition value', () => {
        createWrapper({
          props: {
            initialValues: {
              ...initialValues,
              type: 'FLOW',
              definition: 'flow-definition',
            },
          },
        });

        expect(findDefinitionFlowField().props('value')).toBe('flow-definition');
        expect(findDefinitionThirdPartyFlowField().exists()).toBe(false);
      });
    });

    describe('when flow type is THIRD_PARTY_FLOW', () => {
      it('initializes definitionThirdPartyFlow with definition value', () => {
        createWrapper({
          props: {
            initialValues: {
              ...initialValues,
              type: 'THIRD_PARTY_FLOW',
              definition: 'third-party-definition',
            },
          },
        });

        expect(findDefinitionThirdPartyFlowField().props('value')).toBe('third-party-definition');
        expect(findDefinitionFlowField().exists()).toBe(false);
      });
    });
  });

  describe('Flow Type Field', () => {
    describe('when both feature flags are enabled', () => {
      it('renders the flow type field', () => {
        createWrapper({
          provide: {
            glFeatures: {
              aiCatalogFlows: true,
              aiCatalogThirdPartyFlows: true,
            },
          },
        });

        expect(findFlowType().exists()).toBe(true);
      });
    });

    describe('when only aiCatalogFlows is enabled', () => {
      it('does not render the flow type field', () => {
        createWrapper({
          provide: {
            glFeatures: {
              aiCatalogFlows: true,
              aiCatalogThirdPartyFlows: false,
            },
          },
        });

        expect(findFlowType().exists()).toBe(false);
      });
    });

    describe('when only aiCatalogThirdPartyFlows is enabled', () => {
      it('does not render the flow type field', () => {
        createWrapper({
          provide: {
            glFeatures: {
              aiCatalogFlows: false,
              aiCatalogThirdPartyFlows: true,
            },
          },
        });

        expect(findFlowType().exists()).toBe(false);
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
    const expectedValues = {
      projectId: 'gid://gitlab/Project/1000000',
      name: 'My AI Flow',
      description: 'A helpful AI assistant',
      public: true,
      definition: 'version: "v1"',
      itemType: 'FLOW',
      release: true,
    };

    it('emits form values when user clicks submit', async () => {
      createWrapper({ props: { initialValues } });

      await submitForm();

      expect(wrapper.emitted('submit')).toEqual([[expectedValues]]);
    });

    it('trims the form values before emitting them', async () => {
      const addRandomSpacesToString = (value) => `  ${value}  `;

      const initialValuesWithRandomSpaces = {
        ...initialValues,
        name: addRandomSpacesToString(initialValues.name),
        description: addRandomSpacesToString(initialValues.description),
        definition: addRandomSpacesToString(initialValues.definition),
      };

      createWrapper({ props: { initialValues: initialValuesWithRandomSpaces } });

      await submitForm();

      expect(wrapper.emitted('submit')).toEqual([[expectedValues]]);
    });

    describe('when flow type is FLOW', () => {
      it('emits form values with definition from definitionFlow field', async () => {
        createWrapper({
          props: {
            initialValues: {
              ...initialValues,
              type: 'FLOW',
              definition: 'flow-definition-value',
            },
          },
        });

        await submitForm();

        expect(wrapper.emitted('submit')[0][0]).toMatchObject({
          definition: 'flow-definition-value',
        });
      });
    });

    describe('when flow type is third-party flow', () => {
      const expectedValuesThirdPartyFlow = {
        projectId: 'gid://gitlab/Project/1000000',
        name: 'My AI Flow',
        description: 'A helpful AI assistant',
        definition: 'image:node@22',
        public: true,
        release: true,
        itemType: 'THIRD_PARTY_FLOW',
      };

      it('emits form values on submit', async () => {
        createWrapper({
          props: {
            initialValues: {
              ...initialValues,
              type: 'THIRD_PARTY_FLOW',
              definition: 'image:node@22',
            },
          },
          provide: {
            glFeatures: {
              aiCatalogThirdPartyFlows: true,
            },
          },
        });

        await submitForm();

        expect(wrapper.emitted('submit')).toEqual([[expectedValuesThirdPartyFlow]]);
      });

      it('emits form values with definition from definitionThirdPartyFlow field', async () => {
        createWrapper({
          props: {
            initialValues: {
              ...initialValues,
              type: 'THIRD_PARTY_FLOW',
              definition: 'third-party-definition-value',
            },
          },
        });

        await submitForm();

        expect(wrapper.emitted('submit')[0][0]).toMatchObject({
          definition: 'third-party-definition-value',
        });
      });
    });
  });

  describe('with error messages', () => {
    const mockError = 'The flow could not be created';

    beforeEach(() => {
      createWrapper({ props: { errors: [mockError] } });
    });

    it('passes error alert', () => {
      expect(findErrorAlert().props('errors')).toEqual([mockError]);
    });

    it('renders errors with form errors', async () => {
      const formError = 'Project is required';

      await findProjectDropdown().vm.$emit('error', formError);

      expect(findErrorAlert().props('errors')).toEqual([mockError, formError]);
    });

    it('emits dismiss-errors event', () => {
      findErrorAlert().vm.$emit('dismiss');

      expect(wrapper.emitted('dismiss-errors')).toHaveLength(1);
    });
  });
});
