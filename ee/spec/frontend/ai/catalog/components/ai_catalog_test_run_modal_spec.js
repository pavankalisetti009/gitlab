import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlLink, GlModal, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import AiCatalogTestRunModal from 'ee/ai/catalog/components/ai_catalog_test_run_modal.vue';
import AiCatalogAgentRunForm from 'ee/ai/catalog/components/ai_catalog_agent_run_form.vue';
import executeAiCatalogAgent from 'ee/ai/catalog/graphql/mutations/execute_ai_catalog_agent.mutation.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  mockAgent,
  mockExecuteAgentSuccessResponse,
  mockExecuteAgentErrorResponse,
} from '../mock_data';

Vue.use(VueApollo);

describe('AiCatalogTestRunModal', () => {
  let wrapper;

  const defaultProps = {
    item: mockAgent,
  };

  const executeAiCatalogAgentSuccessHandler = jest
    .fn()
    .mockResolvedValue(mockExecuteAgentSuccessResponse);
  const executeAiCatalogAgentErrorHandler = jest
    .fn()
    .mockResolvedValue(mockExecuteAgentErrorResponse);
  const executeAiCatalogAgentFailedHandler = jest.fn().mockRejectedValue();

  const createComponent = ({
    executeAiCatalogAgentMutationHandler = executeAiCatalogAgentSuccessHandler,
  } = {}) => {
    const apolloProvider = createMockApollo([
      [executeAiCatalogAgent, executeAiCatalogAgentMutationHandler],
    ]);

    wrapper = shallowMountExtended(AiCatalogTestRunModal, {
      apolloProvider,
      propsData: {
        ...defaultProps,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findRunForm = () => wrapper.findComponent(AiCatalogAgentRunForm);
  const findErrorsAlert = () => wrapper.findComponent(ErrorsAlert);
  const findSuccessAlert = () => wrapper.findComponent(GlAlert);

  const userPrompt = 'prompt';

  const submitForm = async () => {
    findRunForm().vm.$emit('submit', { userPrompt });
    await waitForPromises();
  };

  beforeEach(() => {
    createComponent();
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('renders modal with title', () => {
    expect(findModal().props('title')).toBe(`Test run agent: ${mockAgent.name}`);
  });

  it('renders run form', () => {
    expect(findRunForm().exists()).toBe(true);
  });

  describe('on form submit', () => {
    it('executes mutation', async () => {
      await submitForm();

      expect(executeAiCatalogAgentSuccessHandler).toHaveBeenCalledWith({
        input: { agentId: mockAgent.id, userPrompt },
      });
    });

    describe('when request succeeds', () => {
      beforeEach(async () => {
        await submitForm();
        await waitForPromises();
      });

      it('shows success alert with workflow link', () => {
        const workflowLink = findSuccessAlert().findComponent(GlLink);

        expect(findSuccessAlert().text()).toBe('Test run executed successfully, see Session 1.');
        expect(workflowLink.props('href')).toBe('/gitlab-duo/test/-/automate/agent-sessions/1');
      });

      it('does not pass errors to the error alert', () => {
        expect(findErrorsAlert().props('errors')).toHaveLength(0);
      });
    });

    describe('when request succeeds but returns error', () => {
      beforeEach(async () => {
        createComponent({
          executeAiCatalogAgentMutationHandler: executeAiCatalogAgentErrorHandler,
        });
        await submitForm();
        await waitForPromises();
      });

      it('passes errors to the errors alert', () => {
        expect(findErrorsAlert().props('errors')).toStrictEqual(['Could not find agent ID']);
      });

      it('does not show the success alert', () => {
        expect(findSuccessAlert().exists()).toBe(false);
      });
    });

    describe('when request fails', () => {
      beforeEach(async () => {
        createComponent({
          executeAiCatalogAgentMutationHandler: executeAiCatalogAgentFailedHandler,
        });
        await submitForm();
      });

      it('passes errors to the errors alert', () => {
        expect(findErrorsAlert().props('errors')).toStrictEqual(['The test run failed. Error']);
      });

      it('does not show the success alert', () => {
        expect(findSuccessAlert().exists()).toBe(false);
      });
    });
  });

  describe('when the modal emits the hidden event', () => {
    it('emits the hidden event', () => {
      findModal().vm.$emit('hidden');

      expect(wrapper.emitted('hide')).toHaveLength(1);
    });
  });
});
