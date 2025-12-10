import Vue from 'vue';
import VueApollo from 'vue-apollo';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import createAiCatalogFlow from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_flow.mutation.graphql';
import AiCatalogFlowsDuplicate from 'ee/ai/catalog/pages/ai_catalog_flows_duplicate.vue';
import AiCatalogFlowForm from 'ee/ai/catalog/components/ai_catalog_flow_form.vue';
import { VERSION_PINNED, VERSION_LATEST } from 'ee/ai/catalog/constants';
import { AI_CATALOG_FLOWS_SHOW_ROUTE } from 'ee/ai/catalog/router/constants';
import {
  mockFlow,
  mockVersionProp,
  mockCreateAiCatalogFlowSuccessMutation,
  mockCreateAiCatalogFlowErrorMutation,
  mockFlowConfigurationForProject,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');

describe('AiCatalogFlowsDuplicate', () => {
  let wrapper;

  const createAiCatalogFlowMock = jest
    .fn()
    .mockResolvedValue(mockCreateAiCatalogFlowSuccessMutation);
  const mockToast = {
    show: jest.fn(),
  };
  const mockRouter = {
    push: jest.fn(),
  };

  const defaultProps = {
    version: mockVersionProp, // mock defaults to `latestVersion`
    aiCatalogFlow: mockFlow,
  };

  const createComponent = ({ provide = {}, props = {} } = {}) => {
    const apolloProvider = createMockApollo([[createAiCatalogFlow, createAiCatalogFlowMock]]);

    wrapper = shallowMountExtended(AiCatalogFlowsDuplicate, {
      apolloProvider,
      propsData: { ...defaultProps, ...props },
      provide: {
        ...provide,
      },
      mocks: {
        $route: {
          params: { id: 1 },
        },
        $router: mockRouter,
        $toast: mockToast,
      },
    });
  };

  const findForm = () => wrapper.findComponent(AiCatalogFlowForm);

  beforeEach(() => {
    createComponent();
  });

  describe('Form Initial Values', () => {
    beforeEach(async () => {
      await waitForPromises();
    });

    it('sets initial values based on the versionKey, but always private and without a project', async () => {
      const definition = 'This is the pinned version value';
      const expectedInitialValues = {
        name: `Copy of ${mockFlow.name}`,
        description: mockFlow.description,
        definition,
        public: false,
      };

      createComponent({
        props: {
          version: {
            isUpdateAvailable: true,
            activeVersionKey: VERSION_PINNED,
          },
          aiCatalogFlow: {
            ...mockFlow,
            configurationForProject: {
              ...mockFlowConfigurationForProject,
              pinnedItemVersion: {
                ...mockFlowConfigurationForProject.pinnedItemVersion,
                definition,
              },
            },
          },
        },
      });
      await waitForPromises();

      expect(findForm().props('initialValues')).toEqual(expectedInitialValues);
    });

    it('sets initial values based on the latestVersion versionKey, but always private and without a project', async () => {
      const definition = 'This is the latest version value';
      const expectedInitialValues = {
        name: `Copy of ${mockFlow.name}`,
        description: mockFlow.description,
        definition,
        public: false,
      };

      createComponent({
        props: {
          version: {
            isUpdateAvailable: true,
            activeVersionKey: VERSION_LATEST,
          },
          aiCatalogFlow: {
            ...mockFlow,
            latestVersion: {
              ...mockFlow.latestVersion,
              definition,
            },
            configurationForProject: {
              ...mockFlowConfigurationForProject,
              pinnedItemVersion: {
                ...mockFlowConfigurationForProject.pinnedItemVersion,
                definition: 'not expected',
              },
            },
          },
        },
      });
      await waitForPromises();

      expect(findForm().props('initialValues')).toEqual(expectedInitialValues);
    });
  });

  describe('Form Submit', () => {
    const { name, description, project } = mockFlow;
    const formValues = {
      name: `${name} 2`,
      description,
      projectId: project.id,
      definition: mockFlow.definition,
      public: true,
    };

    const submitForm = () => findForm().vm.$emit('submit', formValues);

    beforeEach(async () => {
      await waitForPromises();
    });

    it('sends a create request', () => {
      submitForm();

      expect(createAiCatalogFlowMock).toHaveBeenCalledTimes(1);
      expect(createAiCatalogFlowMock).toHaveBeenCalledWith({
        input: formValues,
      });
    });

    it('sets a loading state on the form while submitting', async () => {
      expect(findForm().props('isLoading')).toBe(false);

      await submitForm();

      expect(findForm().props('isLoading')).toBe(true);
    });

    describe('when request succeeds', () => {
      beforeEach(async () => {
        submitForm();
        await waitForPromises();
      });

      it('shows toast', () => {
        expect(mockToast.show).toHaveBeenCalledWith('Flow created.');
      });

      it('navigates to flows show page', async () => {
        await waitForPromises();
        expect(mockRouter.push).toHaveBeenCalledWith({
          name: AI_CATALOG_FLOWS_SHOW_ROUTE,
          params: { id: 4 },
        });
      });
    });

    describe('when request fails', () => {
      beforeEach(async () => {
        createAiCatalogFlowMock.mockRejectedValue(new Error());
        submitForm();
        await waitForPromises();
      });

      it('sets error messages and captures exception', () => {
        expect(findForm().props('errors')).toEqual([
          'Could not create flow in the project. Check that the project meets the <a href="/help/user/duo_agent_platform/ai_catalog#view-the-ai-catalog" target="_blank">prerequisites</a> and try again.',
        ]);
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
        expect(findForm().props('isLoading')).toBe(false);
      });

      it('allows user to dismiss errors', async () => {
        await findForm().vm.$emit('dismiss-errors');

        expect(findForm().props('errors')).toEqual([]);
      });
    });

    describe('when request succeeds but returns error', () => {
      beforeEach(async () => {
        createAiCatalogFlowMock.mockResolvedValue(mockCreateAiCatalogFlowErrorMutation);
        submitForm();
        await waitForPromises();
      });

      it('shows an alert', () => {
        expect(findForm().props('errors')).toEqual([
          mockCreateAiCatalogFlowErrorMutation.data.aiCatalogFlowCreate.errors[0],
        ]);
        expect(findForm().props('isLoading')).toBe(false);
      });
    });
  });
});
