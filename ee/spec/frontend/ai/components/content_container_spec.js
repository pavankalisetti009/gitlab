import { nextTick } from 'vue';
import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective } from 'helpers/vue_mock_directive';
import AiContentContainer from 'ee/ai/components/content_container.vue';

describe('AiContentContainer', () => {
  let wrapper;

  const activeTabMock = {
    title: 'Test Tab Title',
    component: 'Placeholder content',
  };

  const createComponent = ({ activeTab = activeTabMock, showBackButton = false } = {}) => {
    wrapper = shallowMountExtended(AiContentContainer, {
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      propsData: {
        activeTab,
        isExpanded: true,
        showBackButton,
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
    createComponent();
  });

  it('renders the tab title in the header', () => {
    expect(findPanelTitle().text()).toBe(activeTabMock.title);
  });

  it('renders maximize and collapse buttons', () => {
    expect(findMaximizeButton().exists()).toBe(true);
    expect(findCollapseButton().exists()).toBe(true);
    expect(findCollapseButton().attributes('aria-label')).toBe('Collapse GitLab Duo Panel');
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
});
