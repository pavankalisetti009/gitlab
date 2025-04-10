import { GlBadge, GlIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';

describe('WorkItemStatusBadge', () => {
  let wrapper;

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findBadge = () => wrapper.findComponent(GlBadge);
  const findBadgeText = () => findBadge().text();

  const createComponent = ({
    name = 'Duplicate',
    iconName = 'status-cancelled',
    color = '',
  } = {}) => {
    wrapper = shallowMount(WorkItemStatusBadge, {
      propsData: {
        name,
        iconName,
        color,
      },
    });
  };

  describe('with required props only', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders correctly', () => {
      expect(findBadge().exists()).toBe(true);
      expect(findIcon().exists()).toBe(true);
    });

    it('displays the correct name', () => {
      expect(findBadgeText()).toBe('Duplicate');
    });

    it('passes the correct icon name prop', () => {
      expect(findIcon().props('name')).toBe('status-cancelled');
    });

    it('does not apply color style when color prop is not provided', () => {
      expect(findIcon().attributes('style')).toBeUndefined();
    });
  });

  describe('with all props including color', () => {
    const testColor = '#ff0000';

    it('applies the color style to the icon', () => {
      createComponent({ color: testColor });
      expect(findIcon().attributes('style')).toEqual('color: rgb(255, 0, 0);');
    });
  });
});
