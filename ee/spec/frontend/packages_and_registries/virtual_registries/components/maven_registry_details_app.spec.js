import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlButton } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import MavenRegistryDetailsApp from 'ee/packages_and_registries/virtual_registries/components/maven_registry_details_app.vue';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import MetadataItem from '~/vue_shared/components/registry/metadata_item.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import RegistryUpstreamItem from 'ee/packages_and_registries/virtual_registries/components/registry_upstream_item.vue';
import RegistryUpstreamForm from 'ee/packages_and_registries/virtual_registries/components/registry_upstream_form.vue';
import createUpstreamRegistryMutation from 'ee/packages_and_registries/virtual_registries/graphql/mutations/create_maven_upstream.mutation.graphql';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';

jest.mock('ee/packages_and_registries/virtual_registries/sentry_utils');

Vue.use(VueApollo);

describe('MavenRegistryDetailsApp', () => {
  let wrapper;

  const defaultProps = {
    registry: {
      id: 1,
      name: 'Registry title',
      description: 'Registry description',
    },
    upstreams: [
      {
        id: 1,
        name: 'Upstream title',
        description: 'Upstream description',
        url: 'http://maven.org/test',
        cacheValidityHours: 24,
        position: 1,
        cacheSize: '100 MB',
        canClearCache: true,
        warning: {
          text: 'Example warning text',
        },
      },
    ],
  };

  const defaultProvide = {
    registryEditPath: 'edit_path',
    glAbilities: {
      createVirtualRegistry: true,
      updateVirtualRegistry: true,
    },
  };

  const upstream = {
    name: 'Maven upstream 7',
    url: 'https://repo.maven.apache.org/maven2',
    description: '',
    username: '',
    password: '',
    cacheValidityHours: 24,
  };

  const createUpstreamSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      mavenUpstreamCreate: {
        upstream: {
          id: 7,
          ...upstream,
        },
        errors: [],
      },
    },
  });

  const mockError = new Error('GraphQL error');

  const createUpstreamErrorHandler = jest.fn().mockResolvedValue({
    data: {
      mavenUpstreamCreate: {
        upstream: null,
        errors: ['Name too long'],
      },
    },
  });

  const errorHandler = jest.fn().mockRejectedValue(mockError);
  const showToastSpy = jest.fn();

  const findDescription = () => wrapper.findByTestId('description');
  const findTitleArea = () => wrapper.findComponent(TitleArea);
  const findButton = () => wrapper.findComponent(GlButton);
  const findCrudComponent = () => wrapper.findComponent(CrudComponent);
  const findCreateUpstreamButton = () => wrapper.findByTestId('crud-form-toggle');
  const findMetadataItems = () => wrapper.findAllComponents(MetadataItem);
  const findCreateUpstreamForm = () => wrapper.findComponent(RegistryUpstreamForm);
  const findCreateUpstreamErrorAlert = () => wrapper.findComponent(GlAlert);
  const findUpstreams = () => wrapper.findAllComponents(RegistryUpstreamItem);

  const createComponent = ({
    mountFn = shallowMountExtended,
    props = {},
    provide = {},
    handlers = [],
    stubs = {},
  } = {}) => {
    wrapper = mountFn(MavenRegistryDetailsApp, {
      apolloProvider: createMockApollo(handlers),
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
      stubs: {
        TitleArea,
        ...stubs,
      },
      mocks: {
        $toast: {
          show: showToastSpy,
        },
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
        count: defaultProps.upstreams.length,
        toggleText: 'Add upstream',
      });
    });

    it('does not set toggleText prop on Crud component when user does not have ability', () => {
      createComponent({ provide: { glAbilities: { createVirtualRegistry: false } } });

      expect(findCrudComponent().props('toggleText')).toBeNull();
    });

    it('renders the upstreams and passes correct props to each', () => {
      const upstreams = findUpstreams();

      expect(upstreams).toHaveLength(defaultProps.upstreams.length);
      expect(upstreams.at(0).props()).toMatchObject({
        upstream: defaultProps.upstreams[0],
      });
    });

    it('shows create form when toggleText is clicked', () => {
      findCrudComponent().vm.$emit('toggle');
      expect(findCreateUpstreamForm().exists()).toBe(true);
    });

    it('renders the edit button with correct href', () => {
      expect(findButton().attributes('href')).toBe(defaultProvide.registryEditPath);
    });

    it('hides the edit button if user does not have ability', () => {
      createComponent({ provide: { glAbilities: { updateVirtualRegistry: false } } });

      expect(findButton().exists()).toBe(false);
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

  describe('create upstream action', () => {
    it('emits createUpstream on successful form submission', async () => {
      createComponent({
        handlers: [[createUpstreamRegistryMutation, createUpstreamSuccessHandler]],
        mountFn: mountExtended,
        stubs: {
          RegistryUpstreamItem: true,
          RegistryUpstreamForm,
        },
      });

      await findCreateUpstreamButton().trigger('click');

      await findCreateUpstreamForm().vm.$emit('submit', upstream);

      expect(findCreateUpstreamForm().props('loading')).toBe(true);

      await waitForPromises();

      expect(createUpstreamSuccessHandler).toHaveBeenCalledWith({
        id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Registry/1',
        ...upstream,
      });
      expect(findCreateUpstreamForm().exists()).toBe(false);
      expect(wrapper.emitted('upstreamCreated')).toHaveLength(1);
      expect(showToastSpy).toHaveBeenCalledWith('Upstream created successfully');
      expect(findCreateUpstreamErrorAlert().exists()).toBe(false);
      expect(captureException).not.toHaveBeenCalled();
    });

    describe('with errors', () => {
      it('renders alert with message', async () => {
        createComponent({
          handlers: [[createUpstreamRegistryMutation, createUpstreamErrorHandler]],
        });

        await findCrudComponent().vm.$emit('toggle');

        await findCreateUpstreamForm().vm.$emit('submit', upstream);

        expect(findCreateUpstreamForm().props('loading')).toBe(true);

        await waitForPromises();

        expect(findCreateUpstreamForm().props('loading')).toBe(false);
        expect(findCreateUpstreamErrorAlert().text()).toBe('Name too long');
        expect(showToastSpy).not.toHaveBeenCalled();
        expect(captureException).not.toHaveBeenCalled();
      });

      it('sends an error to Sentry', async () => {
        createComponent({
          handlers: [[createUpstreamRegistryMutation, errorHandler]],
        });

        await findCrudComponent().vm.$emit('toggle');

        await findCreateUpstreamForm().vm.$emit('submit', upstream);

        await waitForPromises();

        expect(findCreateUpstreamErrorAlert().text()).toBe(
          'Something went wrong while creating the upstream. Please try again.',
        );
        expect(findCreateUpstreamForm().props('loading')).toBe(false);
        expect(showToastSpy).not.toHaveBeenCalled();
        expect(captureException).toHaveBeenCalledWith({
          component: 'MavenRegistryDetailsApp',
          error: mockError,
        });
      });
    });
  });
});
