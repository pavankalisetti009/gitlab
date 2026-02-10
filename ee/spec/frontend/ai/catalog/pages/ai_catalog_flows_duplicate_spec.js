import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlExperimentBadge } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import createAiCatalogFlow from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_flow.mutation.graphql';
import AiCatalogFlowsDuplicate from 'ee/ai/catalog/pages/ai_catalog_flows_duplicate.vue';
import AiCatalogFlowForm from 'ee/ai/catalog/components/ai_catalog_flow_form.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { AI_CATALOG_FLOWS_SHOW_ROUTE } from 'ee/ai/catalog/router/constants';
import { VERSION_PINNED, VERSION_PINNED_GROUP, VERSION_LATEST } from 'ee/ai/catalog/constants';
import * as utils from 'ee/ai/catalog/utils';
import {
  mockFlow,
  mockCreateAiCatalogFlowSuccessMutation,
  mockCreateAiCatalogFlowErrorMutation,
  mockFlowConfigurationForProject,
  mockFlowConfigurationForGroup,
  mockFlowVersion,
  mockFlowPinnedVersion,
  mockFlowGroupPinnedVersion,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');

describe('AiCatalogFlowsDuplicate', () => {
  let wrapper;
  let resolveVersionSpy;

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
  const findFormInitialValues = () => findForm().props('initialValues');
  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findExperimentBadge = () => wrapper.findComponent(GlExperimentBadge);

  beforeEach(() => {
    resolveVersionSpy = jest.spyOn(utils, 'resolveVersion').mockReturnValue({
      ...mockFlowVersion,
      key: VERSION_LATEST,
    });
  });

  afterEach(() => {
    resolveVersionSpy.mockRestore();
  });

  describe('Page Heading', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders page heading with correct title and description', () => {
      expect(findPageHeading().exists()).toBe(true);
      expect(findPageHeading().text()).toContain('Duplicate flow');
      expect(findPageHeading().text()).toContain(
        'Duplicate this flow with all its settings and configuration.',
      );
    });

    it('renders experiment badge', () => {
      expect(findExperimentBadge().exists()).toBe(true);
      expect(findExperimentBadge().props('type')).toBe('beta');
    });
  });

  describe('Form Initial Values', () => {
    const baseExpectedInitialValues = {
      name: `Copy of ${mockFlow.name}`,
      description: mockFlow.description,
      public: false,
    };

    const expectedInitialValuesWithProjectPinnedVersion = {
      ...baseExpectedInitialValues,
      definition: mockFlowConfigurationForProject.pinnedItemVersion.definition,
    };

    const expectedInitialValuesWithGroupPinnedVersion = {
      ...baseExpectedInitialValues,
      definition: mockFlowConfigurationForGroup.pinnedItemVersion.definition,
    };

    const expectedInitialValuesWithLatestVersion = {
      ...baseExpectedInitialValues,
      definition: mockFlow.latestVersion.definition,
    };

    it('sets initial item public field and removes project field correctly', async () => {
      createComponent({
        props: {
          aiCatalogFlow: {
            ...mockFlow,
            configurationForProject: {
              ...mockFlowConfigurationForProject,
              public: true,
            },
          },
        },
        provide: {
          isGlobal: false,
          projectId: '1',
        },
      });
      await waitForPromises();

      const initialValues = findFormInitialValues();

      expect(initialValues).not.toHaveProperty('project');
    });

    describe('being set correctly in global context', () => {
      it('sets initial values to latest version', async () => {
        resolveVersionSpy.mockReturnValue({
          ...mockFlowVersion,
          key: VERSION_LATEST,
        });

        const aiCatalogFlow = {
          ...mockFlow,
          configurationForProject: mockFlowConfigurationForProject, // not expected
        };

        createComponent({
          props: {
            aiCatalogFlow,
          },
          provide: {
            isGlobal: true,
          },
        });
        await waitForPromises();

        expect(findFormInitialValues()).toEqual(expectedInitialValuesWithLatestVersion);

        expect(resolveVersionSpy).toHaveBeenCalledWith(
          expect.objectContaining(aiCatalogFlow),
          true,
        );
      });
    });

    describe('being set correctly in project context', () => {
      it('sets initial values to latest version when no configurations are present', async () => {
        resolveVersionSpy.mockReturnValue({
          ...mockFlowVersion,
          key: VERSION_LATEST,
        });

        createComponent({
          props: {
            aiCatalogFlow: mockFlow,
          },
          provide: {
            isGlobal: false,
            projectId: '1',
          },
        });
        await waitForPromises();

        expect(findFormInitialValues()).toEqual(expectedInitialValuesWithLatestVersion);

        expect(resolveVersionSpy).toHaveBeenCalledWith(expect.objectContaining(mockFlow), false);
      });

      it('sets initial values to group-pinned version when only group configuration is present', async () => {
        resolveVersionSpy.mockReturnValue({
          ...mockFlowGroupPinnedVersion,
          key: VERSION_PINNED_GROUP,
        });

        const aiCatalogFlow = { ...mockFlow, configurationForGroup: mockFlowConfigurationForGroup };

        createComponent({
          props: {
            aiCatalogFlow,
          },
          provide: {
            isGlobal: false,
            projectId: '1',
          },
        });
        await waitForPromises();

        expect(findFormInitialValues()).toEqual(expectedInitialValuesWithGroupPinnedVersion);

        expect(resolveVersionSpy).toHaveBeenCalledWith(
          expect.objectContaining(aiCatalogFlow),
          false,
        );
      });

      it('sets initial values to project-pinned version even if group- and project-level configurations are present', async () => {
        resolveVersionSpy.mockReturnValue({
          ...mockFlowPinnedVersion,
          key: VERSION_PINNED,
        });

        const aiCatalogFlow = {
          ...mockFlow,
          configurationForGroup: mockFlowConfigurationForGroup,
          configurationForProject: mockFlowConfigurationForProject,
        };

        createComponent({
          props: {
            aiCatalogFlow,
          },
          provide: {
            isGlobal: false,
            projectId: '1',
          },
        });
        await waitForPromises();

        expect(findFormInitialValues()).toEqual(expectedInitialValuesWithProjectPinnedVersion);

        expect(resolveVersionSpy).toHaveBeenCalledWith(
          expect.objectContaining(aiCatalogFlow),
          false,
        );
      });

      it('sets initial values to latest version when neither the group- nor project-level configurations are present', async () => {
        resolveVersionSpy.mockReturnValue({
          ...mockFlowVersion,
          key: VERSION_LATEST,
        });

        const aiCatalogFlow = {
          ...mockFlow,
          configurationForGroup: null,
          configurationForProject: null,
        };

        createComponent({
          props: {
            aiCatalogFlow,
          },
          provide: {
            isGlobal: false,
            projectId: '1',
          },
        });
        await waitForPromises();

        expect(findFormInitialValues()).toEqual(expectedInitialValuesWithLatestVersion);

        expect(resolveVersionSpy).toHaveBeenCalledWith(
          expect.objectContaining(aiCatalogFlow),
          false,
        );
      });
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
      createComponent();
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

  describe('created hook - redirect behavior', () => {
    it.each([
      {
        name: 'redirects in non-global area without admin permissions',
        isGlobal: false,
        adminAiCatalogItem: false,
        shouldRedirect: true,
      },
      {
        name: 'does not redirect in non-global area with admin permissions',
        isGlobal: false,
        adminAiCatalogItem: true,
        shouldRedirect: false,
      },
      {
        name: 'does not redirect in global area without admin permissions',
        isGlobal: true,
        adminAiCatalogItem: false,
        shouldRedirect: false,
      },
      {
        name: 'does not redirect in global area with admin permissions',
        isGlobal: true,
        adminAiCatalogItem: true,
        shouldRedirect: false,
      },
    ])('$name', ({ isGlobal, adminAiCatalogItem, shouldRedirect }) => {
      createComponent({
        props: {
          aiCatalogFlow: { ...mockFlow, userPermissions: { adminAiCatalogItem } },
        },
        provide: {
          isGlobal,
        },
      });

      if (shouldRedirect) {
        expect(mockRouter.push).toHaveBeenCalledWith({
          name: AI_CATALOG_FLOWS_SHOW_ROUTE,
          params: { id: 1 },
        });
      } else {
        expect(mockRouter.push).not.toHaveBeenCalled();
      }
    });
  });
});
