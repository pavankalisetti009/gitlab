import { nextTick } from 'vue';
import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective } from 'helpers/vue_mock_directive';
import ChatPanel from 'ee/ai/components/chat_panel.vue';

describe('ChatPanel', () => {
  const defaultTitle = 'GitLab Duo Chat';
  const collapseLabel = 'Collapse GitLab Duo Chat';
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(ChatPanel, {
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      propsData: {
        title: defaultTitle,
        isExpanded: true,
      },
      stubs: {
        GlButton,
      },
    });
  };

  const findPanelTitle = () => wrapper.findByTestId('chat-panel-title');
  const findCollapseButton = () => wrapper.findByTestId('chat-panel-collapse-button');

  beforeEach(() => {
    createComponent();
  });

  it('renders the title', () => {
    expect(findPanelTitle().text()).toBe(defaultTitle);
  });

  it('collapses the panel when the collapse button is clicked', async () => {
    await findCollapseButton().trigger('click');
    await nextTick();

    expect(wrapper.emitted('closePanel')).toEqual([[false]]);
  });

  it('passes correct aria-label to the collapse button', () => {
    expect(findCollapseButton().attributes('aria-label')).toBe(collapseLabel);
  });
});
