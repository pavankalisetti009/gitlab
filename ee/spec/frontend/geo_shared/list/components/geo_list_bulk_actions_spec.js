import { GlModal, GlSprintf, GlButton, GlLink } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoListBulkActions from 'ee/geo_shared/list/components/geo_list_bulk_actions.vue';
import { MOCK_BULK_ACTIONS } from '../mock_data';

describe('GeoListBulkActions', () => {
  let wrapper;

  const defaultProvide = {
    itemTitle: 'Test Item',
  };

  const defaultProps = {
    bulkActions: MOCK_BULK_ACTIONS,
  };

  const createComponent = ({ props } = {}) => {
    wrapper = shallowMountExtended(GeoListBulkActions, {
      provide: { ...defaultProvide },
      propsData: { ...defaultProps, ...props },
      stubs: { GlSprintf },
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

  describe('Modal help links', () => {
    describe('when link is not provided', () => {
      beforeEach(() => {
        createComponent();
      });

      it('does not render the modal help link', async () => {
        findBulkActions().at(0).vm.$emit('click');
        await nextTick();

        expect(findGlModal().findComponent(GlLink).exists()).toBe(false);
      });
    });

    describe('when link is provided', () => {
      beforeEach(() => {
        createComponent({
          props: {
            bulkActions: [
              {
                ...MOCK_BULK_ACTIONS[0],
                modal: {
                  title: 'Test title',
                  description: 'Test description',
                  helpLink: {
                    text: 'Help link',
                    href: '/help/link',
                  },
                },
              },
            ],
          },
        });
      });

      it('does render the modal help link', async () => {
        findBulkActions().at(0).vm.$emit('click');
        await nextTick();

        expect(findGlModal().findComponent(GlLink).text()).toBe('Help link');
        expect(findGlModal().findComponent(GlLink).props('href')).toBe('/help/link');
      });
    });
  });
});
