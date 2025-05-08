import { GlButton, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import MavenRegistryItem from 'ee/packages_and_registries/virtual_registries/components/maven_registry_item.vue';

describe('MavenRegistryItem', () => {
  let wrapper;

  const defaultProps = {
    registry: {
      id: 1,
      name: 'Registry name',
    },
  };

  const defaultProvide = {
    basePath: '/groups/gitlab-org/-/virtual_registries/maven',
    glAbilities: {
      updateVirtualRegistry: true,
    },
  };

  const findShowLink = () => wrapper.findComponent(GlLink);
  const findEditButton = () => wrapper.findComponent(GlButton);

  const createComponent = ({ provide = {} } = {}) => {
    wrapper = shallowMountExtended(MavenRegistryItem, {
      propsData: {
        ...defaultProps,
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
      const expectedHref = `${defaultProvide.basePath}/${defaultProps.registry.id}`;
      expect(findShowLink().attributes('href')).toBe(expectedHref);
    });

    it('renders the edit button with correct href when user has permissions', () => {
      const expectedHref = `${defaultProvide.basePath}/${defaultProps.registry.id}/edit`;
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
