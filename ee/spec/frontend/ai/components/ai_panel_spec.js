import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useLocalStorageSpy } from 'helpers/local_storage_helper';
import AIPanel from 'ee/ai/components/ai_panel.vue';
import ChatPanel from 'ee/ai/components/chat_panel.vue';
import NavigationRail from 'ee/ai/components/navigation_rail.vue';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';

describe('AIPanel', () => {
  useLocalStorageSpy();
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(AIPanel, {
      stubs: {
        ChatPanel,
        NavigationRail,
      },
    });
  };

  const findChatPanel = () => wrapper.findComponent(ChatPanel);
  const findNavigationRail = () => wrapper.findComponent(NavigationRail);
  const findLocalStorageSync = () => wrapper.findComponent(LocalStorageSync);

  it('renders chat panel and navigation rail', () => {
    createComponent();

    expect(findChatPanel().exists()).toBe(true);
    expect(findNavigationRail().exists()).toBe(true);
  });

  it('updates localStorage state when toggleAIPanel is emitted from a child', async () => {
    createComponent();
    findLocalStorageSync().vm.$emit('input', false);

    await waitForPromises();

    expect(findChatPanel().props('isExpanded')).toBe(false);
    expect(findNavigationRail().props('isExpanded')).toBe(false);
  });
});
