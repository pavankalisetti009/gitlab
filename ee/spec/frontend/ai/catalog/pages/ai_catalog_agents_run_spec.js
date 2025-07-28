import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AiCatalogAgentsRun from 'ee/ai/catalog/pages/ai_catalog_agents_run.vue';
import AiCatalogAgentRunForm from 'ee/ai/catalog/components/ai_catalog_agent_run_form.vue';
import { mockAgent } from '../mock_data';

describe('AiCatalogAgentsRun', () => {
  let wrapper;

  const defaultProps = {
    aiCatalogAgent: mockAgent,
  };
  const mockToast = {
    show: jest.fn(),
  };

  const createComponent = () => {
    wrapper = shallowMountExtended(AiCatalogAgentsRun, {
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

  it('shows toast with prompt on form submit', () => {
    const mockPrompt = 'Mock prompt';

    findRunForm().vm.$emit('submit', { userPrompt: mockPrompt });

    expect(mockToast.show).toHaveBeenCalledWith(mockPrompt);
  });
});
