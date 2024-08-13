import { GlPopover, GlSprintf, GlLink, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BreakingChangesIcon from 'ee/security_orchestration/components/policies/breaking_changes_icon.vue';

describe('BreakingChangesIcon', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(BreakingChangesIcon, {
      propsData: {
        id: '1',
        content: 'content',
        ...propsData,
      },
      stubs: {
        GlPopover,
        GlSprintf,
      },
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findLink = () => wrapper.findComponent(GlLink);

  it('renders warning icon and popover by default', () => {
    createComponent();

    expect(findIcon().props('name')).toBe('warning');
    expect(findIcon().classes()).toEqual(['gl-text-orange-600']);

    expect(findPopover().text()).toBe('content');
  });

  it('renders warning icon and popover with link', () => {
    createComponent({
      propsData: { content: 'content with %{linkStart}link%{linkEnd}', link: 'link' },
    });

    expect(findPopover().text()).toBe('content with link');
    expect(findLink().attributes('href')).toBe('link');
  });
});
