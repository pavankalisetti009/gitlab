import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import MetadataItem from '~/vue_shared/components/registry/metadata_item.vue';
import MavenRegistryDetailsHeader from 'ee/packages_and_registries/virtual_registries/components/maven_registry_details_header.vue';

describe('MavenRegistryDetailsHeader', () => {
  let wrapper;

  const defaultProvide = {
    registry: {
      id: 1,
      name: 'Registry title',
      description: 'Registry description',
    },
  };

  const findEditButton = () => wrapper.findComponent(GlButton);
  const findTitleArea = () => wrapper.findComponent(TitleArea);
  const findMetadataItem = () => wrapper.findComponent(MetadataItem);
  const findDescription = () => wrapper.findByTestId('description');

  const createComponent = ({ provide = {} } = {}) => {
    wrapper = shallowMountExtended(MavenRegistryDetailsHeader, {
      provide: {
        ...defaultProvide,
        ...provide,
      },
      stubs: {
        TitleArea,
      },
    });
  };

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the TitleArea component with correct props', () => {
      expect(findTitleArea().props('title')).toBe('Registry title');
    });

    it('renders the description', () => {
      expect(findDescription().text()).toBe('Registry description');
    });

    it('displays metadata items', () => {
      expect(findMetadataItem().props('icon')).toBe('infrastructure-registry');
      expect(findMetadataItem().props('text')).toBe('Maven');
    });

    it('does not render Edit button', () => {
      expect(findEditButton().exists()).toBe(false);
    });
  });

  describe('when user has ability to edit', () => {
    beforeEach(() => {
      createComponent({
        provide: {
          registryEditPath: 'registry_edit_path',
          glAbilities: {
            updateVirtualRegistry: true,
          },
        },
      });
    });

    it('renders Edit button', () => {
      expect(findEditButton().text()).toBe('Edit');
      expect(findEditButton().props('href')).toBe('registry_edit_path');
    });
  });
});
