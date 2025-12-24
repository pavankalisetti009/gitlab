import { GlTableLite } from '@gitlab/ui';
import mavenRegistriesPayload from 'test_fixtures/ee/graphql/packages_and_registries/virtual_registries/graphql/queries/get_maven_virtual_registries.query.graphql.json';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import RegistriesTable from 'ee/packages_and_registries/virtual_registries/components/maven/registries_and_upstreams/registries_table.vue';

describe('RegistriesTable', () => {
  let wrapper;

  const defaultProps = {
    registries: mavenRegistriesPayload.data.group.virtualRegistriesPackagesMavenRegistries.nodes,
  };

  const [registry] = defaultProps.registries;
  const registryId = getIdFromGraphQLId(registry.id);

  const defaultProvide = {
    editRegistryPathTemplate: '/groups/gitlab-org/-/virtual_registries/maven/registries/:id/edit',
    showRegistryPathTemplate: '/groups/gitlab-org/-/virtual_registries/maven/registries/:id',
    glAbilities: {
      updateVirtualRegistry: true,
    },
  };

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findRegistryLinks = () => wrapper.findAllByTestId('registry-name');
  const findEditButtons = () => wrapper.findAllByTestId('edit-registry-button');
  const findTimeAgoTooltips = () => wrapper.findAllComponents(TimeAgoTooltip);

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = mountExtended(RegistriesTable, {
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

    it('renders the table with correct fields', () => {
      expect(findTable().props('fields')).toEqual([
        {
          key: 'name',
          label: 'Registry',
          thClass: '!gl-border-t-0',
          tdClass: '@sm/panel:gl-max-w-0 !gl-py-3',
        },
        {
          key: 'updated',
          label: 'Last updated',
          thClass: 'gl-w-20 !gl-border-t-0',
          tdClass: '!gl-py-3',
        },
        {
          key: 'actions',
          label: 'Actions',
          hide: false,
          thClass: 'gl-w-6 gl-text-right !gl-border-t-0',
          tdClass: 'gl-text-right !gl-py-3',
        },
      ]);
    });

    it('renders registry names as links', () => {
      const links = findRegistryLinks();

      expect(links).toHaveLength(1);
      expect(links.at(0).attributes('href')).toBe(
        `/groups/gitlab-org/-/virtual_registries/maven/registries/${registryId}`,
      );
      expect(links.at(0).text()).toBe('registry 1');
    });

    it('displays updated date with TimeAgoTooltip', () => {
      const tooltips = findTimeAgoTooltips();

      expect(tooltips).toHaveLength(1);
      expect(tooltips.at(0).props('time')).toBe(registry.updatedAt);
    });

    it('renders edit button when user has permission', () => {
      const editButtons = findEditButtons();

      expect(editButtons).toHaveLength(1);
      expect(editButtons.at(0).props()).toMatchObject({
        size: 'small',
        category: 'tertiary',
        icon: 'pencil',
        href: `/groups/gitlab-org/-/virtual_registries/maven/registries/${registryId}/edit`,
      });
      expect(editButtons.at(0).attributes('aria-label')).toBe('Edit registry registry 1');
    });

    describe('when user lacks permissions', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            glAbilities: {
              updateVirtualRegistry: false,
            },
          },
        });
      });

      it('does not render edit button', () => {
        expect(findEditButtons()).toHaveLength(0);
      });

      it('hides the table action column', () => {
        expect(findTable().props('fields')).toEqual([
          {
            key: 'name',
            label: 'Registry',
            thClass: '!gl-border-t-0',
            tdClass: '@sm/panel:gl-max-w-0 !gl-py-3',
          },
          {
            key: 'updated',
            label: 'Last updated',
            thClass: 'gl-w-20 !gl-border-t-0',
            tdClass: '!gl-py-3',
          },
        ]);
      });
    });
  });

  describe('with multiple registries', () => {
    const multipleRegistries = [
      ...defaultProps.registries,
      {
        __typename: 'MavenVirtualRegistry',
        id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Registry/9999',
        name: 'Maven Registry 9999',
        updatedAt: '2023-05-18T10:00:00Z',
      },
    ];

    beforeEach(() => {
      createComponent({
        props: {
          registries: multipleRegistries,
        },
      });
    });

    it('renders all registries', () => {
      expect(findRegistryLinks()).toHaveLength(2);
      expect(findEditButtons()).toHaveLength(2);
      expect(findTimeAgoTooltips()).toHaveLength(2);
    });

    it('generates correct URLs for each registry', () => {
      const links = findRegistryLinks();
      const editButtons = findEditButtons();

      expect(links.at(0).attributes('href')).toBe(
        `/groups/gitlab-org/-/virtual_registries/maven/registries/${registryId}`,
      );
      expect(links.at(1).attributes('href')).toBe(
        '/groups/gitlab-org/-/virtual_registries/maven/registries/9999',
      );

      expect(editButtons.at(0).attributes('href')).toBe(
        `/groups/gitlab-org/-/virtual_registries/maven/registries/${registryId}/edit`,
      );
      expect(editButtons.at(1).attributes('href')).toBe(
        '/groups/gitlab-org/-/virtual_registries/maven/registries/9999/edit',
      );
    });
  });

  describe('with empty registries array', () => {
    beforeEach(() => {
      createComponent({
        props: {
          registries: [],
        },
      });
    });

    it('renders table with no items', () => {
      expect(findTable().exists()).toBe(true);
      expect(findRegistryLinks()).toHaveLength(0);
      expect(findEditButtons()).toHaveLength(0);
    });
  });
});
