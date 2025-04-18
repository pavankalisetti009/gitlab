import { GlFilteredSearch, GlTableLite } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import MavenUpstreamDetailsApp from 'ee/packages_and_registries/virtual_registries/components/maven_upstream_details_app.vue';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import MetadataItem from '~/vue_shared/components/registry/metadata_item.vue';

describe('MavenUpstreamDetailsApp', () => {
  let wrapper;

  const defaultProps = {
    upstream: {
      name: 'Test Maven Upstream',
      url: 'https://maven.example.com',
      description: 'This is a test maven upstream',
      cacheEntries: {
        count: 2,
      },
    },
    cacheEntries: {
      nodes: [
        { relativePath: 'com/example/artifact1', size: '1.2MB' },
        { relativePath: 'com/example/artifact2', size: '3.4MB' },
      ],
    },
  };

  const findDescription = () => wrapper.findByTestId('description');
  const findTitleArea = () => wrapper.findComponent(TitleArea);
  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);
  const findTable = () => wrapper.findComponent(GlTableLite);
  const findMetadataItems = () => wrapper.findAllComponents(MetadataItem);

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(MavenUpstreamDetailsApp, {
      propsData: {
        ...defaultProps,
        ...props,
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
      expect(findTitleArea().props('title')).toBe(defaultProps.upstream.name);
    });

    it('renders the description', () => {
      expect(findDescription().text()).toBe(defaultProps.upstream.description);
    });

    it('renders the GlFilteredSearch component', () => {
      expect(findFilteredSearch().props('value')).toStrictEqual([]);
    });

    it('renders the GlTableLite component with correct props', () => {
      expect(findTable().props('fields')).toEqual([
        {
          key: 'relativePath',
          label: 'Artifact',
        },
        {
          key: 'size',
          label: 'Size',
        },
        {
          key: 'actions',
          label: 'Actions',
          thClass: 'hidden',
        },
      ]);
      expect(findTable().vm.$attrs.items).toEqual(defaultProps.cacheEntries.nodes);
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

    it('renders the artifacts count metadata item', () => {
      const countItem = findMetadataItems().at(1);

      expect(countItem.props('icon')).toBe('doc-text');
      expect(countItem.props('text')).toBe('2 Artifacts');
    });

    it('renders the URL metadata item', () => {
      const urlItem = findMetadataItems().at(2);

      expect(urlItem.props('icon')).toBe('earth');
      expect(urlItem.props('text')).toBe(defaultProps.upstream.url);
      expect(urlItem.props('size')).toBe('xl');
    });
  });

  describe('computed properties', () => {
    it('computes artifactsCountText correctly with one artifact', () => {
      createComponent({
        upstream: {
          ...defaultProps.upstream,
          cacheEntries: { count: 1 },
        },
      });

      const countItem = findMetadataItems().at(1);

      expect(countItem.props('text')).toBe('1 Artifact');
    });

    it('computes cacheEntryItems as empty array when nodes is undefined', () => {
      createComponent({
        upstream: {
          ...defaultProps.upstream,
          cacheEntries: { count: 0 },
        },
        cacheEntries: {},
      });
      const countItem = findMetadataItems().at(1);

      expect(findTable().vm.$attrs.items).toEqual([]);
      expect(countItem.props('text')).toBe('0 Artifacts');
    });
  });
});
