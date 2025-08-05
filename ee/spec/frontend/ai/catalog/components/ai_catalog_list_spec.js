import { GlSkeletonLoader, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import AiCatalogListItem from 'ee/ai/catalog/components/ai_catalog_list_item.vue';
import ResourceListsEmptyState from '~/vue_shared/components/resource_lists/empty_state.vue';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import { mockAgents } from '../mock_data';

describe('AiCatalogList', () => {
  let wrapper;

  const mockItems = mockAgents;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AiCatalogList, {
      propsData: {
        items: mockItems,
        itemTypeConfig: {},
        isLoading: false,
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findEmptyState = () => wrapper.findComponent(ResourceListsEmptyState);
  const findList = () => wrapper.find('ul');
  const findListItems = () => wrapper.findAllComponents(AiCatalogListItem);
  const findContainer = () => wrapper.findByTestId('ai-catalog-list');
  const findConfirmModal = () => wrapper.findComponent(ConfirmActionModal);

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the container with correct test id', () => {
      const container = findContainer();

      expect(container.exists()).toBe(true);
      expect(container.element.tagName).toBe('DIV');
    });

    it('renders list when not loading', () => {
      const list = findList();

      expect(list.exists()).toBe(true);
    });

    it('does not render skeleton loader and empty state when not loading and there are items', () => {
      expect(findSkeletonLoader().exists()).toBe(false);
      expect(findEmptyState().exists()).toBe(false);
    });
  });

  describe('loading state', () => {
    it('shows skeleton loader and hides list and empty state when loading is true', () => {
      createComponent({ isLoading: true });

      expect(findSkeletonLoader().exists()).toBe(true);
      expect(findEmptyState().exists()).toBe(false);
      expect(findList().exists()).toBe(false);
    });

    it('shows list and hides skeleton loader when loading is false and there are items', () => {
      createComponent({ isLoading: false });

      expect(findSkeletonLoader().exists()).toBe(false);
      expect(findEmptyState().exists()).toBe(false);
      expect(findList().exists()).toBe(true);
    });
  });

  describe('list items rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders correct number of list items', () => {
      const listItems = findListItems();

      expect(listItems).toHaveLength(3);
    });

    it('passes correct props to each list item', () => {
      const listItems = findListItems();

      listItems.wrappers.forEach((listItem, index) => {
        expect(listItem.props('item')).toEqual(mockItems[index]);
      });
    });

    it('does not render confirm modal', () => {
      expect(findConfirmModal().exists()).toBe(false);
    });
  });

  describe('empty items', () => {
    beforeEach(() => {
      createComponent({ items: [] });
    });

    it('does render the empty state, but no list and skeleton loader when no items provided', () => {
      expect(findEmptyState().exists()).toBe(true);
      expect(findList().exists()).toBe(false);
      expect(findSkeletonLoader().exists()).toBe(false);
    });
  });

  describe('deleting an item', () => {
    const mockDeleteTitle = 'Delete item';
    const mockDeleteMessage = 'Are you sure you want to delete item %{name}?';
    const mockDeleteFn = jest.fn();

    beforeEach(() => {
      createComponent({
        deleteConfirmTitle: mockDeleteTitle,
        deleteConfirmMessage: mockDeleteMessage,
        deleteFn: mockDeleteFn,
      });

      const secondItem = findListItems().at(1);

      secondItem.vm.$emit('delete');
    });

    it('opens confirm modal on delete', () => {
      expect(findConfirmModal().props('title')).toBe(mockDeleteTitle);
      expect(findConfirmModal().text()).toBe(
        `Are you sure you want to delete item ${mockItems[1].name}?`,
      );
    });

    it('calls delete function on confirm', () => {
      findConfirmModal().props('actionFn')();

      expect(mockDeleteFn).toHaveBeenCalledWith(mockItems[1].id);
    });
  });
});
