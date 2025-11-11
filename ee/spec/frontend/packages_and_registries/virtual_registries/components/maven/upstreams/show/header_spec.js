import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import MetadataItem from '~/vue_shared/components/registry/metadata_item.vue';
import UpstreamDetailsHeader from 'ee/packages_and_registries/virtual_registries/components/maven/upstreams/show/header.vue';
import { mockUpstream } from '../../../../mock_data';

describe('UpstreamDetailsHeader', () => {
  let wrapper;

  const defaultProps = {
    upstream: mockUpstream,
  };

  const findEditButton = () => wrapper.findComponent(GlButton);
  const findTitleArea = () => wrapper.findComponent(TitleArea);
  const findAllMetadataItems = () => wrapper.findAllComponents(MetadataItem);
  const findArtifactsCountMetadataItem = () => wrapper.findByTestId('artifacts-count');
  const findDescription = () => wrapper.findByTestId('description');

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(UpstreamDetailsHeader, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
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

    it('displays title area', () => {
      expect(findTitleArea().props('title')).toBe('Upstream Registry');
    });

    it('displays description', () => {
      expect(findDescription().text()).toBe('Upstream registry description');
    });

    it('displays metadata items', () => {
      expect(findAllMetadataItems()).toHaveLength(3);
    });

    it('does not render Edit button', () => {
      expect(findEditButton().exists()).toBe(false);
    });
  });

  describe('when user has ability to edit', () => {
    beforeEach(() => {
      createComponent({
        provide: {
          editUpstreamPath: 'upstream_path',
          glAbilities: {
            updateVirtualRegistry: true,
          },
        },
      });
    });

    it('renders Edit button', () => {
      expect(findEditButton().text()).toBe('Edit');
      expect(findEditButton().props('href')).toBe('upstream_path');
    });
  });

  describe('loading state', () => {
    beforeEach(() => {
      createComponent({
        props: {
          loading: true,
          cacheEntriesCount: 5,
        },
      });
    });

    it('shows loading text for artifacts count', () => {
      expect(findArtifactsCountMetadataItem().props('text')).toBe('-- artifacts');
    });
  });

  describe('with cache entries count', () => {
    beforeEach(() => {
      createComponent({
        props: {
          cacheEntriesCount: 5,
        },
      });
    });

    it('displays correct artifacts count text', () => {
      expect(findArtifactsCountMetadataItem().props('text')).toBe('5 artifacts');
    });
  });
});
