import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlExperimentBadge, GlAlert, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import AiCatalogFlowsEdit from 'ee/ai/catalog/pages/ai_catalog_flows_edit.vue';
import AiCatalogFlowForm from 'ee/ai/catalog/components/ai_catalog_flow_form.vue';
import updateAiCatalogFlow from 'ee/ai/catalog/graphql/mutations/update_ai_catalog_flow.mutation.graphql';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { AI_CATALOG_FLOWS_SHOW_ROUTE } from 'ee/ai/catalog/router/constants';
import {
  mockFlow,
  mockUpdateAiCatalogFlowSuccessMutation,
  mockUpdateAiCatalogFlowNoChangeMutation,
  mockUpdateAiCatalogFlowMetadataOnlyMutation,
  mockUpdateAiCatalogFlowErrorMutation,
  mockFlowConfigurationForProject,
  mockVersionProp,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');

describe('AiCatalogFlowsEdit', () => {
  let wrapper;
  let mockApollo;

  const mockToast = {
    show: jest.fn(),
  };
  const mockRouter = {
    push: jest.fn(),
  };

  const flowId = 4;
  const routeParams = { id: flowId };
  const defaultProps = {
    version: mockVersionProp,
    aiCatalogFlow: mockFlow,
  };

  const mockUpdateAiCatalogFlowHandler = jest
    .fn()
    .mockResolvedValue(mockUpdateAiCatalogFlowSuccessMutation);

  const createComponent = ({ props } = {}) => {
    mockApollo = createMockApollo([[updateAiCatalogFlow, mockUpdateAiCatalogFlowHandler]]);

    wrapper = shallowMountExtended(AiCatalogFlowsEdit, {
      apolloProvider: mockApollo,
      propsData: { ...defaultProps, ...props },
      mocks: {
        $route: {
          params: routeParams,
        },
        $router: mockRouter,
        $toast: mockToast,
      },
    });
  };

  const findForm = () => wrapper.findComponent(AiCatalogFlowForm);
  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findExperimentBadge = () => wrapper.findComponent(GlExperimentBadge);
  const findEditingLatestVersionWarning = () => wrapper.findComponent(GlAlert);
  const findEditVersionWarningText = () =>
    findEditingLatestVersionWarning().findComponent(GlSprintf).attributes('message');

  describe('Page Heading', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders page heading with correct title and description', () => {
      expect(findPageHeading().exists()).toBe(true);
      expect(findPageHeading().text()).toContain('Edit flow');
      expect(findPageHeading().text()).toContain('Manage flow settings.');
    });

    it('renders experiment badge', () => {
      expect(findExperimentBadge().exists()).toBe(true);
      expect(findExperimentBadge().props('type')).toBe('beta');
    });
  });

  describe('Initial Rendering', () => {
    it('render edit form', () => {
      createComponent();
      expect(findForm().exists()).toBe(true);
    });

    it('renders initial values with expected version data', async () => {
      const expectedInitialValues = {
        name: mockFlow.name,
        description: mockFlow.description,
        projectId: 'gid://gitlab/Project/1',
        definition: mockFlow.latestVersion.definition,
        public: true,
      };

      createComponent({
        props: {
          version: mockVersionProp,
          aiCatalogFlow: {
            ...mockFlow,
            configurationForProject: {
              ...mockFlowConfigurationForProject,
              pinnedItemVersion: {
                ...mockFlowConfigurationForProject.pinnedItemVersion,
                definition: 'this is not expected',
              },
            },
          },
        },
      });
      await waitForPromises();

      expect(findForm().props('initialValues')).toEqual(expectedInitialValues);
    });
  });

  describe('version update availability behaviour', () => {
    it('shows warning when version update is available', async () => {
      createComponent({
        props: {
          version: {
            isUpdateAvailable: true,
          },
        },
      });
      await waitForPromises();

      expect(findEditingLatestVersionWarning().exists()).toBe(true);
      expect(findEditVersionWarningText()).toContain(
        'To prevent versioning issues, you can edit only the latest version of this flow. To edit an earlier version,',
      );
      expect(findEditVersionWarningText()).toContain('duplicate the flow');
    });

    it('does not show warning when item is at the latest version already', async () => {
      createComponent({
        props: {
          version: {
            isUpdateAvailable: false,
          },
        },
      });
      await waitForPromises();

      expect(findEditingLatestVersionWarning().exists()).toBe(false);
    });
  });

  describe('Form Submit', () => {
    const { name, description, latestVersion } = mockFlow;
    const formValues = {
      name,
      description,
      public: true,
      definition: latestVersion.definition,
    };

    const submitForm = () => findForm().vm.$emit('submit', formValues);

    beforeEach(() => {
      createComponent();
    });

    it('sends an update request', async () => {
      await findForm().vm.$emit('submit', formValues);
      await waitForPromises();

      expect(mockUpdateAiCatalogFlowHandler).toHaveBeenCalledTimes(1);
      expect(mockUpdateAiCatalogFlowHandler).toHaveBeenCalledWith({
        input: { ...formValues, id: mockFlow.id },
      });
    });

    it('sets a loading state on the form while submitting', async () => {
      expect(findForm().props('isLoading')).toBe(false);

      await findForm().vm.$emit('submit', {});
      expect(findForm().props('isLoading')).toBe(true);
    });

    describe('when request succeeds with version change', () => {
      beforeEach(async () => {
        submitForm();
        await waitForPromises();
      });

      it('shows toast when version was updated', () => {
        expect(mockToast.show).toHaveBeenCalledWith('Flow updated.');
      });
    });

    describe('when request succeeds with metadata change only', () => {
      beforeEach(async () => {
        mockUpdateAiCatalogFlowHandler.mockResolvedValue(
          mockUpdateAiCatalogFlowMetadataOnlyMutation,
        );
        submitForm();
        await waitForPromises();
      });

      it('shows toast when metadata was updated', () => {
        expect(mockToast.show).toHaveBeenCalledWith('Flow updated.');
      });
    });

    describe('when request succeeds without any change', () => {
      beforeEach(async () => {
        mockUpdateAiCatalogFlowHandler.mockResolvedValue(mockUpdateAiCatalogFlowNoChangeMutation);
        submitForm();
        await waitForPromises();
      });

      it('does not show toast when nothing was updated', () => {
        expect(mockToast.show).not.toHaveBeenCalled();
      });

      it('navigates to flows show page', async () => {
        await waitForPromises();
        expect(mockRouter.push).toHaveBeenCalledWith({
          name: AI_CATALOG_FLOWS_SHOW_ROUTE,
          params: { id: flowId },
        });
      });
    });

    describe('when request fails', () => {
      beforeEach(async () => {
        mockUpdateAiCatalogFlowHandler.mockRejectedValue(new Error());
        submitForm();
        await waitForPromises();
      });

      it('sets error messages and captures exception', () => {
        expect(findForm().props('errors')).toEqual(['Could not update flow. Try again.']);
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
        mockUpdateAiCatalogFlowHandler.mockResolvedValue(mockUpdateAiCatalogFlowErrorMutation);
        submitForm();
        await waitForPromises();
      });

      it('shows an alert', () => {
        expect(findForm().props('errors')).toEqual([
          mockUpdateAiCatalogFlowErrorMutation.data.aiCatalogFlowUpdate.errors[0],
        ]);
        expect(findForm().props('isLoading')).toBe(false);
      });
    });
  });

  describe('created hook - redirect behavior', () => {
    it.each([
      {
        name: 'redirects when adminAiCatalogItem is false',
        adminAiCatalogItem: false,
        shouldRedirect: true,
      },
      {
        name: 'does not redirect when adminAiCatalogItem is true',
        adminAiCatalogItem: true,
        shouldRedirect: false,
      },
    ])('$name', ({ adminAiCatalogItem, shouldRedirect }) => {
      createComponent({
        props: { aiCatalogFlow: { ...mockFlow, userPermissions: { adminAiCatalogItem } } },
      });

      if (shouldRedirect) {
        expect(mockRouter.push).toHaveBeenCalledWith({
          name: AI_CATALOG_FLOWS_SHOW_ROUTE,
          params: { id: flowId },
        });
      } else {
        expect(mockRouter.push).not.toHaveBeenCalled();
      }
    });
  });
});
