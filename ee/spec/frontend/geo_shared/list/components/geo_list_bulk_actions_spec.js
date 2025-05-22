import { GlModal, GlSprintf, GlButton } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoListBulkActions from 'ee/geo_shared/list/components/geo_list_bulk_actions.vue';

const MOCK_MODAL_DEFINITION = {
  title: 'Test action on %{type}',
  description: 'Executes action on %{type}',
};

describe('GeoListBulkActions', () => {
  let wrapper;

  const defaultProvide = {
    itemTitle: 'Test Item',
  };

  const defaultProps = {
    bulkActions: [
      {
        id: 'test_action',
        text: 'Test Action',
        action: 'TEST_ACTION',
        modal: MOCK_MODAL_DEFINITION,
      },
      {
        id: 'test_action2',
        text: 'Test Action 2',
        action: 'TEST_ACTION_2',
        modal: MOCK_MODAL_DEFINITION,
      },
    ],
  };

  const createComponent = () => {
    wrapper = shallowMountExtended(GeoListBulkActions, {
      provide: { ...defaultProvide },
      propsData: { ...defaultProps },
      stubs: { GlModal, GlSprintf },
    });
  };

  const findBulkActions = () => wrapper.findAllComponents(GlButton);
  const findGlModal = () => wrapper.findComponent(GlModal);

  describe('Actions', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders a button for each bulk action', () => {
      expect(findBulkActions()).toHaveLength(defaultProps.bulkActions.length);
    });
  });

  describe('Modal', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not have content before action is clicked', () => {
      expect(findGlModal().props('title')).toBeNull();
      expect(findGlModal().text()).toBe('');
    });

    it('properly renders when bulk action is clicked', async () => {
      findBulkActions().at(0).vm.$emit('click');
      await nextTick();

      expect(findGlModal().props('title')).toBe(`Test action on ${defaultProvide.itemTitle}`);
      expect(findGlModal().text()).toContain(`Executes action on ${defaultProvide.itemTitle}`);
    });

    it('properly emits `bulkAction` when modal primary action is executed', async () => {
      findBulkActions().at(0).vm.$emit('click');
      await nextTick();

      findGlModal().vm.$emit('primary');
      await nextTick();

      expect(wrapper.emitted('bulkAction')).toStrictEqual([[defaultProps.bulkActions[0].action]]);
    });
  });
});
