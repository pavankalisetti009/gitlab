import { GlButton, GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import MavenRegistryItem from 'ee/packages_and_registries/virtual_registries/components/maven_registry_item.vue';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';

describe('MavenRegistryItem', () => {
  let wrapper;

  const defaultProps = {
    registry: {
      id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Registry/2',
      name: 'Registry name',
      updatedAt: '2023-10-11T10:00:00Z',
    },
  };

  const defaultProvide = {
    editPathTemplate: '/groups/gitlab-org/-/virtual_registries/maven/:id/edit',
    showPathTemplate: '/groups/gitlab-org/-/virtual_registries/maven/:id',
    glAbilities: {
      updateVirtualRegistry: true,
    },
  };

  const findShowLink = () => wrapper.findComponent(GlLink);
  const findEditButton = () => wrapper.findComponent(GlButton);
  const findUpdatedAt = () => wrapper.findComponent(TimeAgoTooltip);

  const createComponent = ({ provide = {} } = {}) => {
    wrapper = shallowMountExtended(MavenRegistryItem, {
      propsData: {
        ...defaultProps,
      },
      stubs: {
        GlSprintf,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the registry name', () => {
      expect(findShowLink().text()).toBe(defaultProps.registry.name);
    });

    it('renders the link to the show page with correct href', () => {
      const expectedHref = `/groups/gitlab-org/-/virtual_registries/maven/2`;
      expect(findShowLink().attributes('href')).toBe(expectedHref);
    });

    it('sets `TimeAgoTooltip` time prop to `updatedAt` time', () => {
      expect(findUpdatedAt().props('time')).toBe(defaultProps.registry.updatedAt);
    });

    it('renders the edit button with correct href when user has permissions', () => {
      const expectedHref = `/groups/gitlab-org/-/virtual_registries/maven/2/edit`;
      expect(findEditButton().exists()).toBe(true);
      expect(findEditButton().attributes('href')).toBe(expectedHref);
    });

    it('does not render the edit button when user does not have permissions', () => {
      createComponent({
        provide: {
          glAbilities: {
            updateVirtualRegistry: false,
          },
        },
      });

      expect(findEditButton().exists()).toBe(false);
    });
  });
});
