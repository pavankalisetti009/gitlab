import { GlAvatar } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import NamespaceMetadata from 'ee/analytics/analytics_dashboards/components/visualizations/namespace_metadata.vue';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { mockGroupNamespaceMetadata } from 'ee_jest/analytics/analytics_dashboards/mock_data';

describe('Namespace Metadata Visualization', () => {
  let wrapper;

  const defaultProps = { data: mockGroupNamespaceMetadata };

  const createWrapper = ({ props = defaultProps } = {}) => {
    wrapper = shallowMountExtended(NamespaceMetadata, {
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      propsData: {
        ...props,
      },
    });
  };

  const findNamespaceAvatar = () => wrapper.findComponent(GlAvatar);
  const findNamespaceTypeIcon = () =>
    wrapper.findByTestId('namespace-metadata-namespace-type-icon');
  const findNamespaceVisibilityIcon = () =>
    wrapper.findByTestId('namespace-metadata-visibility-icon');

  describe('default', () => {
    beforeEach(() => {
      createWrapper();
    });

    it("should render namespace's full name", () => {
      expect(wrapper.findByText('GitLab Org').exists()).toBe(true);
    });

    it('should render namespace type', () => {
      expect(wrapper.findByText('Group').exists()).toBe(true);
    });

    it('should render namespace type icon', () => {
      expect(findNamespaceTypeIcon().props()).toMatchObject({
        name: 'group',
        variant: 'subtle',
      });
    });

    it('should render avatar', () => {
      expect(findNamespaceAvatar().props()).toMatchObject({
        entityName: 'GitLab Org',
        entityId: 225,
        src: '/avatar.png',
        shape: 'rect',
        fallbackOnError: true,
        size: 48,
        alt: `GitLab Org's avatar`,
      });
    });

    it('should render visibility level icon', () => {
      const tooltip = getBinding(findNamespaceVisibilityIcon().element, 'gl-tooltip');

      expect(tooltip).toBeDefined();

      expect(findNamespaceVisibilityIcon().props()).toMatchObject({
        name: 'earth',
        variant: 'subtle',
      });
      expect(findNamespaceVisibilityIcon().attributes('title')).toBe(
        'Public - The group and any public projects can be viewed without any authentication.',
      );
    });
  });
});
