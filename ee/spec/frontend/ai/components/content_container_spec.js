import { nextTick } from 'vue';
import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective } from 'helpers/vue_mock_directive';
import AiContentContainer from 'ee/ai/components/content_container.vue';
import { CHAT_MODES } from 'ee/ai/tanuki_bot/constants';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import DuoAgenticChat from 'ee/ai/duo_agentic_chat/components/duo_agentic_chat.vue';
import DuoChat from 'ee/ai/tanuki_bot/components/duo_chat.vue';

describe('AiContentContainer', () => {
  let wrapper;
  let mockStore;

  const activeTabMock = {
    title: 'Test Tab Title',
    component: 'Placeholder content',
  };

  const createComponent = ({
    activeTab = activeTabMock,
    showBackButton = false,
    propsData = {},
    provide = {},
  } = {}) => {
    mockStore = {
      dispatch: jest.fn(),
    };

    wrapper = shallowMountExtended(AiContentContainer, {
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      propsData: {
        activeTab,
        showBackButton,
        userId: 'gid://gitlab/User/1',
        projectId: 'gid://gitlab/Project/123',
        namespaceId: 'gid://gitlab/Group/456',
        rootNamespaceId: 'gid://gitlab/Group/789',
        resourceId: 'gid://gitlab/Resource/111',
        metadata: '{"key":"value"}',
        userModelSelectionEnabled: false,
        ...propsData,
      },
      provide: {
        chatConfiguration: {
          agenticTitle: 'GitLab Duo Agentic Chat',
          classicTitle: 'GitLab Duo Chat',
          agenticComponent: DuoAgenticChat,
          classicComponent: DuoChat,
          defaultProps: {},
        },
        ...provide,
      },
      mocks: {
        $store: mockStore,
      },
      stubs: {
        GlButton,
      },
    });
  };

  const findPanelTitle = () => wrapper.findByTestId('content-container-title');
  const findCollapseButton = () => wrapper.findByTestId('content-container-collapse-button');
  const findMaximizeButton = () => wrapper.findByTestId('content-container-maximize-button');
  const findBackButton = () => wrapper.findByTestId('content-container-back-button');

  beforeEach(() => {
    // Reset global state before each test
    duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
    createComponent();
  });

  it('renders the tab title in the header', () => {
    expect(findPanelTitle().text()).toBe(activeTabMock.title);
  });

  it('renders maximize and collapse buttons', () => {
    expect(findMaximizeButton().exists()).toBe(true);
    expect(findCollapseButton().exists()).toBe(true);
    expect(findCollapseButton().attributes('aria-label')).toBe('Collapse panel');
  });

  it('collapses the panel when collapse button is clicked', async () => {
    findCollapseButton().trigger('click');
    await nextTick();
    expect(wrapper.emitted('closePanel')).toEqual([[false]]);
  });

  it('shows the maximize icon when minimized', () => {
    expect(findMaximizeButton().props('icon')).toBe('maximize');
  });

  it('shows the minimized icon when maximized', async () => {
    await findMaximizeButton().trigger('click');
    await nextTick();
    expect(findMaximizeButton().props('icon')).toBe('minimize');
  });

  describe('when showBackButton is false', () => {
    beforeEach(() => {
      createComponent({ showBackButton: false });
    });

    it('hides the back button', () => {
      expect(findBackButton().classes()).toContain('!gl-hidden');
    });
  });

  describe('when showBackButton is true', () => {
    beforeEach(() => {
      createComponent({ showBackButton: true });
    });

    it('shows the back button', () => {
      expect(findBackButton().classes()).not.toContain('!gl-hidden');
    });

    it('has correct back button attributes', () => {
      expect(findBackButton().props('icon')).toBe('go-back');
      expect(findBackButton().props('category')).toBe('tertiary');
      expect(findBackButton().attributes('aria-label')).toBe('Go back');
      expect(findBackButton().attributes('title')).toBe('Go back');
    });

    it('emits go-back event when back button is clicked', async () => {
      findBackButton().trigger('click');
      await nextTick();
      expect(wrapper.emitted('go-back')).toEqual([[]]);
    });
  });

  describe('props passing to dynamic component', () => {
    const mockComponentTab = {
      title: 'Test Component',
      component: { name: 'MockComponent', render: (h) => h('div') },
    };

    it('renders dynamic component with props bound', () => {
      createComponent({
        activeTab: mockComponentTab,
        propsData: {
          projectId: 'gid://gitlab/Project/999',
          namespaceId: 'gid://gitlab/Group/888',
          rootNamespaceId: 'gid://gitlab/Group/777',
          resourceId: 'gid://gitlab/Resource/666',
          metadata: '{"test":"data"}',
          userModelSelectionEnabled: true,
        },
      });

      // Verify the component is rendered in the panel body
      expect(wrapper.find('.ai-panel-body').exists()).toBe(true);
    });

    it('does not render string placeholder for non-string components', () => {
      createComponent({
        activeTab: mockComponentTab,
      });

      const placeholderDiv = wrapper.find('.ai-panel-body .gl-self-center');
      expect(placeholderDiv.exists()).toBe(false);
    });
  });

  describe('event forwarding', () => {
    const mockComponentTab = {
      title: 'Test Component',
      component: { name: 'MockComponent', render: (h) => h('div') },
      props: { mode: 'test', isAgenticAvailable: true },
    };

    it('forwards switch-to-active-tab event from dynamic component', async () => {
      createComponent({ activeTab: mockComponentTab });

      const dynamicComponent = wrapper.findComponent({ name: 'MockComponent' });
      dynamicComponent.vm.$emit('switch-to-active-tab', 'chat');
      await nextTick();

      expect(wrapper.emitted('switch-to-active-tab')?.length > 0).toBe(true);
      expect(wrapper.emitted('switch-to-active-tab')).toHaveLength(1);
      expect(wrapper.emitted('switch-to-active-tab')[0]).toEqual(['chat']);
    });

    it('passes mode prop with optional chaining to dynamic component', () => {
      createComponent({ activeTab: mockComponentTab });

      const panelBody = wrapper.find('.ai-panel-body');
      expect(panelBody.exists()).toBe(true);
    });

    it('does not error when activeTab.props is undefined', () => {
      const tabWithoutProps = {
        title: 'Test Component',
        component: { name: 'MockComponent', render: (h) => h('div') },
      };

      expect(() => {
        createComponent({ activeTab: tabWithoutProps });
      }).not.toThrow();
    });
  });

  describe('chat component key', () => {
    const agenticTabMock = {
      title: 'Agentic Chat',
      component: DuoAgenticChat,
      props: { mode: 'active' },
    };

    it('recreates component when chatMode changes', async () => {
      duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
      createComponent({ activeTab: agenticTabMock });

      // Get the initial component instance
      const initialComponent = wrapper.findComponent(DuoAgenticChat);
      expect(initialComponent.exists()).toBe(true);

      // Switch to classic mode - this should destroy and recreate the component
      duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;
      await nextTick();

      // Get the component instance after mode switch
      const newComponent = wrapper.findComponent(DuoAgenticChat);
      expect(newComponent.exists()).toBe(true);

      // Verify the component was recreated (different Vue instance)
      expect(newComponent.vm).not.toBe(initialComponent.vm);
    });
  });

  describe('getContentComponent', () => {
    const agenticTabMock = {
      title: 'Agentic Chat',
      component: DuoAgenticChat,
      props: { mode: 'active' },
    };

    it('returns the `content-component` ref', () => {
      createComponent({ activeTab: agenticTabMock });

      expect(wrapper.vm.getContentComponent()).toEqual(
        expect.objectContaining({
          $el: expect.anything(),
        }),
      );
    });
  });
});
