import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlExperimentBadge } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import createAiCatalogFlow from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_flow.mutation.graphql';
import AiCatalogFlowsNew from 'ee/ai/catalog/pages/ai_catalog_flows_new.vue';
import AiCatalogFlowForm from 'ee/ai/catalog/components/ai_catalog_flow_form.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { AI_CATALOG_FLOWS_SHOW_ROUTE } from 'ee/ai/catalog/router/constants';
import {
  mockFlow,
  mockCreateAiCatalogFlowSuccessMutation,
  mockCreateAiCatalogFlowErrorMutation,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');

describe('AiCatalogFlowsNew', () => {
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

  const createComponent = ({ provide = {} } = {}) => {
    const apolloProvider = createMockApollo([[createAiCatalogFlow, createAiCatalogFlowMock]]);

    wrapper = shallowMountExtended(AiCatalogFlowsNew, {
      apolloProvider,
      provide: {
        ...provide,
      },
      mocks: {
        $router: mockRouter,
        $toast: mockToast,
      },
    });
  };

  const findForm = () => wrapper.findComponent(AiCatalogFlowForm);
  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findExperimentBadge = () => wrapper.findComponent(GlExperimentBadge);

  beforeEach(() => {
    createComponent();
  });

  describe('Page Heading', () => {
    it('renders page heading with correct title and description', () => {
      expect(findPageHeading().exists()).toBe(true);
      expect(findPageHeading().text()).toContain('New flow');
      expect(findPageHeading().text()).toContain(
        'Use flows to automate complex, multi-step tasks.',
      );
    });

    it('renders experiment badge', () => {
      expect(findExperimentBadge().exists()).toBe(true);
      expect(findExperimentBadge().props('type')).toBe('beta');
    });
  });

  describe('Form Submit', () => {
    const { name, description, project, latestVersion } = mockFlow;
    const formValues = {
      name,
      description,
      projectId: project.id,
      public: true,
      definition: latestVersion.definition,
    };

    const submitForm = () => findForm().vm.$emit('submit', formValues);

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
