import { shallowMount } from '@vue/test-utils';
import { GlIcon, GlPopover, GlLink, GlSprintf } from '@gitlab/ui';
import FoundationalIcon from 'ee/ai/components/foundational_icon.vue';

describe('FoundationalIcon', () => {
  let wrapper;

  const defaultProps = {
    resourceId: 'gid://gitlab/Ai::Catalog::Item/1',
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMount(FoundationalIcon, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findLink = () => wrapper.findComponent(GlLink);

  const findPrintText = () => wrapper.findComponent(GlSprintf);

  beforeEach(() => {
    createComponent();
  });

  it('uses tanuki-verified icon', () => {
    expect(findIcon().props('name')).toBe('tanuki-verified');
  });

  it('renders icon with correct id based on resourceId', () => {
    expect(findIcon().attributes('id')).toBe('gid://gitlab/Ai::Catalog::Item/1-foundational-icon');
  });

  it('renders with custom size', () => {
    createComponent({ size: 16 });
    expect(findIcon().props('size')).toBe(16);
  });

  it('renders with default size', () => {
    expect(findIcon().props('size')).toBe(24);
  });

  describe('popover', () => {
    it('renders popover with correct target', () => {
      expect(findPopover().props('target')).toBe(
        'gid://gitlab/Ai::Catalog::Item/1-foundational-icon',
      );
    });

    it('renders popover content with GitLab text', () => {
      expect(findPrintText().attributes('message')).toBe(
        'Created and maintained by %{boldStart}GitLab%{boldEnd}',
      );
    });

    it('renders help page link', () => {
      const link = findLink();

      expect(link.exists()).toBe(true);
      expect(link.props('href')).toBe(
        '/help/user/duo_agent_platform/agents/foundational_agents/_index.md',
      );
      expect(link.props('target')).toBe('_blank');
      expect(link.text()).toBe('Learn more about foundational agents');
    });
  });
});
