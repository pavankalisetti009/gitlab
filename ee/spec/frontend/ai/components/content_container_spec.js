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

  const createComponent = ({ activeTab = activeTabMock } = {}) => {
    wrapper = shallowMountExtended(AiContentContainer, {
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      propsData: {
        activeTab,
        isExpanded: true,
      },
      stubs: {
        GlButton,
      },
    });
  };

  const findPanelTitle = () => wrapper.findByTestId('content-container-title');
  const findCollapseButton = () => wrapper.findByTestId('content-container-collapse-button');
  const findMaximizeButton = () => wrapper.findByTestId('content-container-maximize-button');

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
});
