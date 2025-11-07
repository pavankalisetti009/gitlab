import { GlKeysetPagination, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import AiCatalogListItem from 'ee/ai/catalog/components/ai_catalog_list_item.vue';
import AiCatalogListSkeleton from 'ee/ai/catalog/components/ai_catalog_list_skeleton.vue';
import ResourceListsEmptyState from '~/vue_shared/components/resource_lists/empty_state.vue';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import { mockAgents, mockPageInfo, mockItemTypeConfig } from '../mock_data';

describe('AiCatalogList', () => {
  let wrapper;

  const mockItems = mockAgents;

  const mockDeleteTitle = 'Delete item';
  const mockDeleteMessage = 'Are you sure you want to delete item %{name}?';
  const mockDeleteFn = jest.fn();

  const createComponent = ({ props = {}, slots = {} } = {}) => {
    wrapper = shallowMountExtended(AiCatalogList, {
      propsData: {
        items: mockItems,
        itemTypeConfig: mockItemTypeConfig,
        isLoading: false,
        pageInfo: mockPageInfo,
        deleteConfirmTitle: mockDeleteTitle,
        deleteConfirmMessage: mockDeleteMessage,
        deleteFn: mockDeleteFn,
        ...props,
      },
      slots,
      stubs: {
        GlSprintf,
      },
    });
  };

  const findLoadingStateList = () => wrapper.findComponent(AiCatalogListSkeleton);
  const findEmptyState = () => wrapper.findComponent(ResourceListsEmptyState);
  const findListItems = () => wrapper.findAllComponents(AiCatalogListItem);
  const findConfirmModal = () => wrapper.findComponent(ConfirmActionModal);
  const findPaginator = () => wrapper.findComponent(GlKeysetPagination);

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not render the loading state component', () => {
      expect(findLoadingStateList().exists()).toBe(false);
    });

    it('does render list items', () => {
      const listItems = findListItems();

      expect(listItems).toHaveLength(3);
    });

    it('passes correct props to each list item', () => {
      const listItems = findListItems();

      listItems.wrappers.forEach((listItem, index) => {
        expect(listItem.props('item')).toEqual(mockItems[index]);
      });
    });

    it('does not render empty state', () => {
      expect(findEmptyState().exists()).toBe(false);
    });

    it('does not render the confirm modal by default', () => {
      expect(findConfirmModal().exists()).toBe(false);
    });

    describe('when loading data', () => {
      beforeEach(() => {
        createComponent({
          props: {
            isLoading: true,
          },
        });
      });

      it('renders loading state component', () => {
        const loadingStateList = findLoadingStateList();

        expect(loadingStateList.exists()).toBe(true);
        expect(loadingStateList.props('showRightElement')).toBe(false);
      });

      it('renders loading state with right-hand component placeholder', () => {
        createComponent({
          props: {
            isLoading: true,
            itemTypeConfig: { ...mockItemTypeConfig, deleteActionItem: () => [] },
          },
        });
        const loadingStateList = findLoadingStateList();

        expect(loadingStateList.props('showRightElement')).toBe(true);
      });

      it('does not render list items', () => {
        const listItems = findListItems();

        expect(listItems).toHaveLength(0);
      });

      it('does not render empty state', () => {
        expect(findEmptyState().exists()).toBe(false);
      });
    });

    describe('when data is loaded and there are no items', () => {
      beforeEach(() => {
        createComponent({
          props: { items: [] },
        });
      });

      it('does not render the loading state component', () => {
        expect(findLoadingStateList().exists()).toBe(false);
      });

      it('does not render list items', () => {
        const listItems = findListItems();

        expect(listItems).toHaveLength(0);
      });

      it('renders default empty state with correct props', () => {
        expect(findEmptyState().props()).toMatchObject({
          title: 'Get started with the AI Catalog',
          description: 'Build agents and flows to automate tasks and solve complex problems.',
        });
      });

      it('renders default empty state with search prop', () => {
        createComponent({
          props: { items: [], search: '' },
        });

        expect(findEmptyState().props()).toMatchObject({
          title: 'Get started with the AI Catalog',
          description: 'Build agents and flows to automate tasks and solve complex problems.',
          search: '',
        });
      });

      it('renders custom empty state', () => {
        createComponent({
          props: { items: [] },
          slots: {
            'empty-state': '<div data-testid="custom-empty-state">Custom empty state</div>',
          },
        });

        expect(wrapper.findByTestId('custom-empty-state').exists()).toBe(true);
        expect(findEmptyState().exists()).toBe(false);
      });
    });
  });

  describe('deleting an item', () => {
    beforeEach(() => {
      createComponent();
      const secondItem = findListItems().at(1);

      secondItem.vm.$emit('delete');
    });

    it('opens confirm modal on delete', () => {
      expect(findConfirmModal().props()).toMatchObject({
        title: mockDeleteTitle,
        actionText: 'Delete',
      });
      expect(findConfirmModal().text()).toBe(
        `Are you sure you want to delete item ${mockItems[1].name}?`,
      );
    });

    it('calls delete function on confirm', () => {
      findConfirmModal().props('actionFn')();

      expect(mockDeleteFn).toHaveBeenCalledWith(mockItems[1]);
    });

    describe('with itemTypeConfig', () => {
      beforeEach(() => {
        createComponent({
          props: {
            itemTypeConfig: {
              ...mockItemTypeConfig,
              deleteActionItem: {
                text: 'Remove',
              },
            },
          },
        });
        const secondItem = findListItems().at(1);
        secondItem.vm.$emit('delete');
      });

      it('passes correct actionText to modal', () => {
        expect(findConfirmModal().props('actionText')).toBe('Remove');
      });
    });
  });

  describe('pagination', () => {
    beforeEach(() => {
      createComponent();
    });

    it('passes pageInfo to pagination component', () => {
      expect(findPaginator().props()).toMatchObject({
        startCursor: mockPageInfo.startCursor,
        endCursor: mockPageInfo.endCursor,
        hasNextPage: mockPageInfo.hasNextPage,
        hasPreviousPage: mockPageInfo.hasPreviousPage,
      });
    });

    it('emits prev-page when prev emitted by pagination component', () => {
      findPaginator().vm.$emit('prev');
      expect(wrapper.emitted('prev-page')).toHaveLength(1);
    });

    it('emits next-page when next emitted by pagination component', () => {
      findPaginator().vm.$emit('next');
      expect(wrapper.emitted('next-page')).toHaveLength(1);
    });
  });
});
