import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useLocalStorageSpy } from 'helpers/local_storage_helper';
import AIPanel from 'ee/ai/components/ai_panel.vue';
import AiContentContainer from 'ee/ai/components/content_container.vue';
import NavigationRail from 'ee/ai/components/navigation_rail.vue';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';

describe('AIPanel', () => {
  useLocalStorageSpy();
  let wrapper;

  const createComponent = ({ activeTab = 'chat', isExpanded = true } = {}) => {
    wrapper = shallowMountExtended(AIPanel, {
      data() {
        return {
          activeTab,
          isExpanded,
        };
      },
      stubs: {
        AiContentContainer,
        NavigationRail,
      },
    });
  };

  const findContentContainer = () => wrapper.findComponent(AiContentContainer);
  const findNavigationRail = () => wrapper.findComponent(NavigationRail);
  const findLocalStorageSync = () => wrapper.findComponent(LocalStorageSync);

  it('renders content container and navigation rail', () => {
    createComponent();
    expect(findContentContainer().exists()).toBe(true);
    expect(findNavigationRail().exists()).toBe(true);
  });

  it('syncs expansion state via localStorage when updated by local-storage-sync', async () => {
    createComponent();
    findLocalStorageSync().vm.$emit('input', false);
    await waitForPromises();

    expect(findNavigationRail().props('isExpanded')).toBe(false);
  });

  it('emits collapse and clears tab when the active tab is toggled again', async () => {
    createComponent({ activeTab: 'chat' });
    findNavigationRail().vm.$emit('handleTabToggle', 'chat');
    await waitForPromises();

    expect(findContentContainer().exists()).toBe(false);
  });

  it('activates new tab and expands if collapsed', async () => {
    createComponent({ activeTab: null, isExpanded: false });
    findNavigationRail().vm.$emit('handleTabToggle', 'suggestions');

    await waitForPromises();

    expect(findContentContainer().exists()).toBe(true);
    expect(findContentContainer().props('activeTab')).toEqual({
      title: 'Suggestions',
      component: 'Suggestions content placeholder',
    });
    expect(findContentContainer().props('isExpanded')).toBe(true);
  });
});
