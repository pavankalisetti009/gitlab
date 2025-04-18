import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import MavenRegistryDetailsApp from 'ee/packages_and_registries/virtual_registries/components/maven_registry_details_app.vue';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import MetadataItem from '~/vue_shared/components/registry/metadata_item.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';

describe('MavenRegistryDetailsApp', () => {
  let wrapper;

  const defaultProps = {
    registry: {
      id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Registry/1',
      name: 'Registry title',
      description: 'Registry description',
    },
    upstreams: {
      count: 1,
      nodes: [
        {
          id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/1',
          name: 'Upstream title',
          description: 'Upstream description',
          url: 'http://maven.org/test',
          cacheValidityHours: 24,
          position: 1,
        },
      ],
      pageInfo: {
        startCursor: 'eyJ1cHN0cmVhbV9pZCI6IjEifQ',
        hasNextPage: false,
        hasPreviousPage: false,
        endCursor: 'eyJ1cHN0cmVhbV9pZCI6IjEifQ',
      },
    },
  };

  const defaultProvide = {
    mavenVirtualRegistryEditPath: 'edit_path',
  };

  const findDescription = () => wrapper.findByTestId('description');
  const findTitleArea = () => wrapper.findComponent(TitleArea);
  const findButton = () => wrapper.findComponent(GlButton);
  const findCrudComponent = () => wrapper.findComponent(CrudComponent);
  const findMetadataItems = () => wrapper.findAllComponents(MetadataItem);

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(MavenRegistryDetailsApp, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...defaultProvide,
      },
      stubs: {
        TitleArea,
      },
    });
  };

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the TitleArea component with correct props', () => {
      expect(findTitleArea().props('title')).toBe(defaultProps.registry.name);
    });

    it('renders the description', () => {
      expect(findDescription().text()).toBe(defaultProps.registry.description);
    });

    it('renders the Crud component with correct props', () => {
      expect(findCrudComponent().props()).toMatchObject({
        title: 'Upstreams',
        icon: 'infrastructure-registry',
        count: defaultProps.upstreams.count,
      });
    });

    it('renders the edit button with correct href', () => {
      expect(findButton().attributes('href')).toBe(defaultProvide.mavenVirtualRegistryEditPath);
    });
  });

  describe('metadata items', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the registry type metadata item', () => {
      const registryTypeItem = findMetadataItems().at(0);

      expect(registryTypeItem.props('icon')).toBe('infrastructure-registry');
      expect(registryTypeItem.props('text')).toBe('Maven');
    });
  });
});
