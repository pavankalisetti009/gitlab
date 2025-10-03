import { GlButton, GlSkeletonLoader, GlTable, GlTruncate } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import MavenUpstreamsTable from 'ee/packages_and_registries/virtual_registries/components/maven/registries_and_upstreams/upstreams_table.vue';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { mockUpstreams } from '../../../mock_data';

describe('MavenUpstreamsTable', () => {
  let wrapper;

  const defaultProps = {
    upstreams: mockUpstreams.map(convertObjectPropsToCamelCase),
    busy: false,
  };

  const defaultProvide = {
    editUpstreamPathTemplate: '/groups/gitlab-org/-/virtual_registries/maven/upstreams/:id/edit',
    showUpstreamPathTemplate: '/groups/gitlab-org/-/virtual_registries/maven/upstreams/:id',
    glAbilities: {
      updateVirtualRegistry: true,
    },
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findUpstreamLinks = () => wrapper.findAllByTestId('upstream-name');
  const findEditButtons = () => wrapper.findAllComponents(GlButton);
  const findTruncateComponents = () => wrapper.findAllComponents(GlTruncate);

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = mountExtended(MavenUpstreamsTable, {
      propsData: {
        ...defaultProps,
        ...props,
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

    it('renders the table with correct props', () => {
      expect(findTable().props('fields')).toEqual([
        {
          key: 'name',
          label: 'Upstream',
          tdClass: '@sm/panel:gl-max-w-0',
        },
        {
          key: 'actions',
          label: 'Actions',
          thAlignRight: true,
          thClass: 'gl-w-26',
          tdClass: 'gl-text-right',
        },
      ]);
    });

    it('renders upstream names as links', () => {
      const links = findUpstreamLinks();

      expect(links).toHaveLength(2);
      expect(links.at(0).attributes('href')).toBe(
        '/groups/gitlab-org/-/virtual_registries/maven/upstreams/1',
      );
      expect(links.at(1).attributes('href')).toBe(
        '/groups/gitlab-org/-/virtual_registries/maven/upstreams/2',
      );
    });

    it('renders upstream names and URLs with truncation', () => {
      const truncateComponents = findTruncateComponents();

      expect(truncateComponents.at(0).props()).toMatchObject({
        text: 'Maven Central',
        withTooltip: true,
      });
      expect(truncateComponents.at(1).props()).toMatchObject({
        text: 'https://repo1.maven.org/maven2/',
        withTooltip: true,
      });
    });

    it('displays cache validity hours correctly', () => {
      expect(wrapper.findByTestId('cache-validity-hours').text()).toBe('Artifact cache: 24 hours');
    });

    it('displays metadata cache validity hours correctly', () => {
      expect(wrapper.findByTestId('metadata-cache-validity-hours').text()).toBe(
        'Metadata cache: 12 hours',
      );
    });

    it('renders edit buttons when user has permissions', () => {
      const editButtons = findEditButtons();

      expect(editButtons).toHaveLength(2);
      expect(editButtons.at(0).props()).toMatchObject({
        size: 'small',
        category: 'tertiary',
        icon: 'pencil',
        href: '/groups/gitlab-org/-/virtual_registries/maven/upstreams/1/edit',
      });
      expect(editButtons.at(0).attributes('aria-label')).toBe('Edit upstream Maven Central');
    });

    it('does not render edit buttons when user lacks permissions', () => {
      createComponent({
        provide: {
          glAbilities: {
            updateVirtualRegistry: false,
          },
        },
      });

      expect(findEditButtons()).toHaveLength(0);
    });
  });

  describe('when busy', () => {
    beforeEach(() => {
      createComponent({ props: { busy: true } });
    });

    it('shows skeleton loader', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
    });
  });

  describe('cache validity labels', () => {
    it('handles singular hour correctly', () => {
      createComponent({
        props: {
          upstreams: [
            {
              id: 1,
              name: 'Test',
              url: 'https://test.com',
              cacheValidityHours: 1,
              metadataCacheValidityHours: 1,
            },
          ],
        },
      });

      expect(wrapper.findByTestId('cache-validity-hours').text()).toBe('Artifact cache: 1 hour');
      expect(wrapper.findByTestId('metadata-cache-validity-hours').text()).toBe(
        'Metadata cache: 1 hour',
      );
    });
  });
});
