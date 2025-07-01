import { GlFormTextarea } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AiCatalogAgentsRun from 'ee/ai/catalog/pages/ai_catalog_agents_run.vue';

describe('AiCatalogAgentsRun', () => {
  let wrapper;

  const agentId = '941';

  const mockRouter = {
    back: jest.fn(),
  };

  const mockToast = {
    show: jest.fn(),
  };

  const createComponent = () => {
    wrapper = shallowMountExtended(AiCatalogAgentsRun, {
      mocks: {
        $route: {
          params: { id: agentId },
        },
        $router: mockRouter,
        $toast: mockToast,
      },
    });
  };

  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findBackButton = () => wrapper.findByTestId('ai-catalog-back-button');
  const findSubmitButton = () => wrapper.findByTestId('ai-catalog-run-button');
  const findForm = () => wrapper.find('form');
  const findTextarea = () => wrapper.findComponent(GlFormTextarea);

  beforeEach(() => {
    createComponent();
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('renders page heading', () => {
    expect(findPageHeading().props('heading')).toBe(`Run agent: ${agentId}`);
  });

  it('renders the back button', () => {
    expect(findBackButton().text()).toBe('Go back');
  });

  it('renders form with submit button', () => {
    expect(findForm().exists()).toBe(true);
    expect(findSubmitButton().text()).toBe('Run');
  });

  it('calls router.back when back button is clicked', async () => {
    await findBackButton().vm.$emit('click');

    expect(mockRouter.back).toHaveBeenCalledTimes(1);
  });

  it('shows toast with prompt on form submit', () => {
    const mockPrompt = 'Mock prompt';

    findTextarea().vm.$emit('input', mockPrompt);

    findForm().trigger('submit');

    expect(mockToast.show).toHaveBeenCalledWith(mockPrompt);
  });
});
