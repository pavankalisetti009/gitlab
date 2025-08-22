import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AiCatalogAgentsRun from 'ee/ai/catalog/pages/ai_catalog_agents_run.vue';
import AiCatalogAgentRunForm from 'ee/ai/catalog/components/ai_catalog_agent_run_form.vue';
import executeAiCatalogAgent from 'ee/ai/catalog/graphql/mutations/execute_ai_catalog_agent.mutation.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mockAgent, mockExecuteAgentResponse } from '../mock_data';

Vue.use(VueApollo);

describe('AiCatalogAgentsRun', () => {
  let wrapper;

  const defaultProps = {
    aiCatalogAgent: mockAgent,
  };
  const mockToast = {
    show: jest.fn(),
  };

  const executeAiCatalogAgentSuccessHandler = jest.fn().mockResolvedValue(mockExecuteAgentResponse);
  const executeAiCatalogAgentErrorHandler = jest.fn().mockRejectedValue();

  const createComponent = ({
    executeAiCatalogAgentMutationHandler = executeAiCatalogAgentSuccessHandler,
  } = {}) => {
    const apolloProvider = createMockApollo([
      [executeAiCatalogAgent, executeAiCatalogAgentMutationHandler],
    ]);

    wrapper = shallowMountExtended(AiCatalogAgentsRun, {
      apolloProvider,
      propsData: {
        ...defaultProps,
      },
      mocks: {
        $toast: mockToast,
      },
    });
  };

  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findRunForm = () => wrapper.findComponent(AiCatalogAgentRunForm);

  const submitForm = async () => {
    findRunForm().vm.$emit('submit', { userPrompt: 'prompt' });
    await waitForPromises();
  };

  beforeEach(() => {
    createComponent();
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('renders page heading', () => {
    expect(findPageHeading().props('heading')).toBe(`Run agent: ${mockAgent.name}`);
  });

  it('renders run form', () => {
    expect(findRunForm().exists()).toBe(true);
  });

  describe('on form submit', () => {
    it('executes mutation', async () => {
      await submitForm();

      expect(executeAiCatalogAgentSuccessHandler).toHaveBeenCalledWith({
        input: { agentId: mockAgent.id },
      });
    });

    it('shows success toast', async () => {
      await submitForm();

      expect(mockToast.show).toHaveBeenCalledWith('Agent executed successfully.');
    });

    describe('when something goes wrong', () => {
      it('shows failure toast', async () => {
        createComponent({
          executeAiCatalogAgentMutationHandler: executeAiCatalogAgentErrorHandler,
        });
        await submitForm();

        expect(mockToast.show).toHaveBeenCalledWith('Failed to execute agent.');
      });
    });
  });
});
