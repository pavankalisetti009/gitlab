import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import MavenRegistryDetailsApp from 'ee/packages_and_registries/virtual_registries/components/maven_registry_details_app.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import AddUpstream from 'ee/packages_and_registries/virtual_registries/components/add_upstream.vue';
import RegistryUpstreamItem from 'ee/packages_and_registries/virtual_registries/components/registry_upstream_item.vue';
import RegistryUpstreamForm from 'ee/packages_and_registries/virtual_registries/components/registry_upstream_form.vue';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';
import createUpstreamRegistryMutation from 'ee/packages_and_registries/virtual_registries/graphql/mutations/create_maven_upstream.mutation.graphql';
import {
  deleteMavenUpstreamCache,
  deleteMavenRegistryCache,
  getMavenUpstreamRegistriesList,
  updateMavenRegistryUpstreamPosition,
} from 'ee/api/virtual_registries_api';
import { mavenVirtualRegistry } from '../mock_data';

jest.mock('ee/api/virtual_registries_api');
jest.mock('ee/packages_and_registries/virtual_registries/sentry_utils');

Vue.use(VueApollo);

describe('MavenRegistryDetailsApp', () => {
  let wrapper;

  const { upstreams } = mavenVirtualRegistry;

  const defaultProps = {
    registryId: 1,
    upstreams,
  };

  const defaultProvide = {
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

  const upstreamsResponse = {
    data: [
      {
        id: 3,
        name: 'test',
        description: '',
        group_id: 122,
        url: 'https://gitlab.com',
        username: '',
        cache_validity_hours: 24,
        metadata_cache_validity_hours: 24,
        created_at: '2025-07-15T04:10:03.060Z',
        updated_at: '2025-07-15T04:11:00.426Z',
      },
    ],
    headers: {
      'x-total': '1',
    },
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

  const mockGraphQLError = new Error('GraphQL error');

  const createUpstreamErrorHandler = jest.fn().mockResolvedValue({
    data: {
      mavenUpstreamCreate: {
        upstream: null,
        errors: ['Name too long'],
      },
    },
  });

  const errorHandler = jest.fn().mockRejectedValue(mockGraphQLError);
  const showToastSpy = jest.fn();

  const findAddUpstream = () => wrapper.findComponent(AddUpstream);
  const findClearRegistryCacheButton = () => wrapper.findByTestId('clear-registry-cache-button');
  const findCrudComponent = () => wrapper.findComponent(CrudComponent);
  const findClearRegistryCacheModal = () => wrapper.findByTestId('clear-registry-cache-modal');
  const findClearUpstreamCacheModal = () => wrapper.findByTestId('clear-upstream-cache-modal');
  const findCreateUpstreamForm = () => wrapper.findComponent(RegistryUpstreamForm);
  const findCreateUpstreamErrorAlert = () => wrapper.findComponent(GlAlert);
  const findUpstreamItems = () => wrapper.findAllComponents(RegistryUpstreamItem);
  const findUpdateActionErrorAlert = () => wrapper.findByTestId('update-action-error-alert');

  const createComponent = ({ props = {}, glAbilities = {}, handlers = [], stubs = {} } = {}) => {
    wrapper = shallowMountExtended(MavenRegistryDetailsApp, {
      apolloProvider: createMockApollo(handlers),
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        groupPath: 'full-path',
        glAbilities: {
          ...defaultProvide.glAbilities,
          ...glAbilities,
        },
      },
      stubs: {
        CrudComponent,
        ...stubs,
      },
      mocks: {
        $toast: {
          show: showToastSpy,
        },
      },
    });
  };

  beforeEach(() => {
    getMavenUpstreamRegistriesList.mockResolvedValue(upstreamsResponse);
  });

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('calls getMavenUpstreamRegistriesList API', () => {
      expect(getMavenUpstreamRegistriesList).toHaveBeenCalledWith({ id: 'full-path' });
    });

    it('renders the Crud component with correct props', () => {
      expect(findCrudComponent().props()).toMatchObject({
        title: 'Upstreams',
        icon: 'infrastructure-registry',
        count: defaultProps.upstreams.length,
      });
    });

    it('renders `Clear all caches` button', () => {
      expect(findClearRegistryCacheButton().exists()).toBe(true);
    });

    it('renders AddUpstreamAction component with `canLink` set to false', () => {
      expect(findAddUpstream().props('canLink')).toBe(false);
    });

    it('renders the upstreams and passes correct props to each', () => {
      const upstreamItems = findUpstreamItems();

      expect(upstreamItems).toHaveLength(defaultProps.upstreams.length);
      expect(upstreamItems.at(0).props()).toMatchObject({
        upstream: defaultProps.upstreams[0],
      });
    });

    it('shows create form when AddUpstreamAction component emits create event', async () => {
      createComponent();
      await findAddUpstream().vm.$emit('create');

      expect(findCreateUpstreamForm().exists()).toBe(true);
      expect(findAddUpstream().props('disabled')).toBe(true);
    });

    it('hides the registry clear cache modal', () => {
      expect(findClearRegistryCacheModal().props('visible')).toBe(false);
    });

    it('hides the upstream clear cache modal', () => {
      expect(findClearUpstreamCacheModal().props('visible')).toBe(false);
    });
  });

  describe('when user does not have ability to create', () => {
    beforeEach(() => {
      createComponent({
        glAbilities: { createVirtualRegistry: false },
      });
    });

    it('does not render AddUpstreamAction component', () => {
      expect(findAddUpstream().exists()).toBe(false);
    });
  });

  describe('when user does not have ability to update', () => {
    beforeEach(() => {
      createComponent({
        glAbilities: { updateVirtualRegistry: false },
      });
    });

    it('does not call getMavenUpstreamRegistriesList API', () => {
      expect(getMavenUpstreamRegistriesList).not.toHaveBeenCalled();
    });

    it('does not show `Clear all caches` button', () => {
      expect(findClearRegistryCacheButton().exists()).toBe(false);
    });

    it('renders AddUpstreamAction component with `canLink` set to false', () => {
      expect(findAddUpstream().props('canLink')).toBe(false);
    });
  });

  describe('when registry has no upstreams', () => {
    beforeEach(() => {
      createComponent({
        props: {
          upstreams: [],
        },
      });
    });

    it('does not show `Clear all caches` button', () => {
      expect(findClearRegistryCacheButton().exists()).toBe(false);
    });

    it('renders AddUpstreamAction component with `canLink` set to true', () => {
      expect(findAddUpstream().props('canLink')).toBe(true);
    });
  });

  describe('create upstream action', () => {
    it('emits createUpstream on successful form submission', async () => {
      createComponent({
        handlers: [[createUpstreamRegistryMutation, createUpstreamSuccessHandler]],
      });

      await findAddUpstream().vm.$emit('create');

      await findCreateUpstreamForm().vm.$emit('submit', upstream);

      expect(findCreateUpstreamForm().props('loading')).toBe(true);

      await waitForPromises();

      expect(createUpstreamSuccessHandler).toHaveBeenCalledWith({
        id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Registry/1',
        ...upstream,
      });
      expect(findCreateUpstreamForm().exists()).toBe(false);
      expect(wrapper.emitted('upstreamCreated')).toHaveLength(1);
      expect(showToastSpy).toHaveBeenCalledWith('Upstream created successfully.');
      expect(findCreateUpstreamErrorAlert().exists()).toBe(false);
      expect(captureException).not.toHaveBeenCalled();
    });

    describe('with errors', () => {
      it('renders alert with message', async () => {
        createComponent({
          handlers: [[createUpstreamRegistryMutation, createUpstreamErrorHandler]],
        });

        await findAddUpstream().vm.$emit('create');

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

        await findAddUpstream().vm.$emit('create');

        await findCreateUpstreamForm().vm.$emit('submit', upstream);

        await waitForPromises();

        expect(findCreateUpstreamErrorAlert().text()).toBe(
          'Something went wrong while creating the upstream. Try again.',
        );
        expect(findCreateUpstreamForm().props('loading')).toBe(false);
        expect(showToastSpy).not.toHaveBeenCalled();
        expect(captureException).toHaveBeenCalledWith({
          component: 'MavenRegistryDetailsApp',
          error: mockGraphQLError,
        });
      });
    });
  });

  describe('update upstream position action', () => {
    beforeEach(() => {
      updateMavenRegistryUpstreamPosition.mockReset();
    });

    describe('when API succeeds', () => {
      beforeEach(() => {
        updateMavenRegistryUpstreamPosition.mockResolvedValue();
        createComponent();
      });

      it('when direction is `down` calculates the right position', async () => {
        const upstreamItems = findUpstreamItems();

        await upstreamItems.at(0).vm.$emit('reorderUpstream', 'down', upstreams[0]);

        expect(updateMavenRegistryUpstreamPosition).toHaveBeenCalledWith({
          id: 2,
          position: 2,
        });
      });

      it('when direction is `up`, calculates the right position', async () => {
        const upstreamItems = findUpstreamItems();

        await upstreamItems.at(1).vm.$emit('reorderUpstream', 'up', upstreams[1]);

        expect(updateMavenRegistryUpstreamPosition).toHaveBeenCalledWith({
          id: 3,
          position: 1,
        });
      });

      it('emits upstreamReordered when successful', async () => {
        const upstreamItems = findUpstreamItems();

        await upstreamItems.at(1).vm.$emit('reorderUpstream', 'up', upstreams[1]);

        await waitForPromises();

        expect(wrapper.emitted('upstreamReordered')).toHaveLength(1);
        expect(showToastSpy).toHaveBeenCalledWith(
          'Position of the upstream has been updated successfully.',
        );
        expect(findUpdateActionErrorAlert().exists()).toBe(false);
        expect(captureException).not.toHaveBeenCalled();
      });
    });

    describe('when API fails', () => {
      it('shows alert with message & reports error to Sentry', async () => {
        const mockError = { error: 'position does not have a valid value' };
        updateMavenRegistryUpstreamPosition.mockRejectedValue(mockError);
        createComponent();

        const upstreamItems = findUpstreamItems();

        await upstreamItems.at(0).vm.$emit('reorderUpstream', 'up', upstreams[0]);

        await waitForPromises();

        expect(findUpdateActionErrorAlert().text()).toBe('position does not have a valid value');
        expect(showToastSpy).not.toHaveBeenCalled();
        expect(captureException).toHaveBeenCalledWith({
          component: 'MavenRegistryDetailsApp',
          error: mockError,
        });
      });

      it('shows alert with default message & reports error to Sentry', async () => {
        const mockError = new Error();
        updateMavenRegistryUpstreamPosition.mockRejectedValue(mockError);
        createComponent();

        const upstreamItems = findUpstreamItems();

        await upstreamItems.at(0).vm.$emit('reorderUpstream', 'down', upstreams[0]);

        await waitForPromises();

        expect(findUpdateActionErrorAlert().text()).toBe(
          'Failed to update position of the upstream. Try again.',
        );
        expect(showToastSpy).not.toHaveBeenCalled();
        expect(captureException).toHaveBeenCalledWith({
          component: 'MavenRegistryDetailsApp',
          error: mockError,
        });
      });
    });
  });

  describe('clear registry cache action', () => {
    beforeEach(() => {
      deleteMavenRegistryCache.mockReset();
    });

    it('modal is shown with props', async () => {
      createComponent();

      await findClearRegistryCacheButton().vm.$emit('click');

      expect(findClearRegistryCacheModal().props('visible')).toBe(true);
      expect(findClearRegistryCacheModal().props('title')).toBe('Clear all caches?');
      expect(findClearRegistryCacheModal().text()).toBe(
        'This will delete all cached packages for exclusive upstream registries in this virtual registry. If any upstream is unavailable or misconfigured after clearing, jobs that rely on those packages might fail. Are you sure you want to continue?',
      );
    });

    it('hides modal on cancel', () => {
      createComponent();

      findClearRegistryCacheButton().vm.$emit('click');

      findClearRegistryCacheModal().vm.$emit('canceled');

      expect(findClearRegistryCacheModal().props('visible')).toBe(false);
    });

    describe('when modal is confirmed and API succeeds', () => {
      beforeEach(() => {
        deleteMavenRegistryCache.mockResolvedValue();
        createComponent();

        findClearRegistryCacheButton().vm.$emit('click');
        findClearRegistryCacheModal().vm.$emit('primary');
      });

      it('calls the right arguments', () => {
        expect(deleteMavenRegistryCache).toHaveBeenCalledWith({
          id: 1,
        });
      });

      it('shows success toast', async () => {
        await waitForPromises();

        expect(showToastSpy).toHaveBeenCalledWith('Registry cache cleared successfully.');
        expect(captureException).not.toHaveBeenCalled();
      });
    });

    describe('when modal is confirmed and API fails', () => {
      it('shows toast with default message & reports error to Sentry', async () => {
        const mockError = new Error();
        deleteMavenRegistryCache.mockRejectedValue(mockError);
        createComponent();

        findClearRegistryCacheButton().vm.$emit('click');
        findClearRegistryCacheModal().vm.$emit('primary');

        await waitForPromises();

        expect(findUpdateActionErrorAlert().text()).toBe(
          'Failed to clear registry cache. Try again.',
        );
        expect(showToastSpy).not.toHaveBeenCalled();
        expect(captureException).toHaveBeenCalledWith({
          component: 'MavenRegistryDetailsApp',
          error: mockError,
        });
      });
    });
  });

  describe('clear upstream cache action', () => {
    beforeEach(() => {
      deleteMavenUpstreamCache.mockReset();
    });

    it('modal is shown with props', async () => {
      createComponent();

      const upstreamItems = findUpstreamItems();
      await upstreamItems.at(0).vm.$emit('clearCache', upstreams[0]);

      expect(findClearUpstreamCacheModal().props()).toMatchObject({
        visible: true,
        title: 'Clear cache for Maven upstream?',
        size: 'sm',
        modalId: 'clear-upstream-cache-modal',
        actionPrimary: {
          text: 'Clear cache',
          attributes: { variant: 'danger', category: 'primary' },
        },
        actionCancel: { text: 'Cancel' },
      });
      expect(findClearUpstreamCacheModal().text()).toBe(
        'This will delete all cached packages for this upstream and re-fetch them from the source. If the upstream is unavailable or misconfigured, jobs might fail. Are you sure you want to continue?',
      );
    });

    it('hides modal on cancel', () => {
      createComponent();

      const upstreamItems = findUpstreamItems();
      upstreamItems.at(0).vm.$emit('clearCache', upstreams[0]);

      findClearUpstreamCacheModal().vm.$emit('canceled');

      expect(findClearUpstreamCacheModal().props('visible')).toBe(false);
    });

    describe('when modal is confirmed', () => {
      beforeEach(() => {
        deleteMavenUpstreamCache.mockResolvedValue();
        createComponent();
        const upstreamItems = findUpstreamItems();

        upstreamItems.at(0).vm.$emit('clearCache', upstreams[0]);
        findClearUpstreamCacheModal().vm.$emit('primary');
      });

      it('calls the right arguments', () => {
        expect(deleteMavenUpstreamCache).toHaveBeenCalledWith({
          id: 2,
        });
      });

      it('shows success toast when successful', async () => {
        await waitForPromises();

        expect(showToastSpy).toHaveBeenCalledWith('Upstream cache cleared successfully.');
        expect(captureException).not.toHaveBeenCalled();
      });
    });

    describe('when API fails', () => {
      it('shows toast with default message & reports error to Sentry', async () => {
        const mockError = new Error();
        deleteMavenUpstreamCache.mockRejectedValue(mockError);
        createComponent();

        const upstreamItems = findUpstreamItems();

        upstreamItems.at(0).vm.$emit('clearCache', upstreams[0]);
        findClearUpstreamCacheModal().vm.$emit('primary');

        await waitForPromises();

        expect(findUpdateActionErrorAlert().text()).toBe(
          'Failed to clear upstream cache. Try again.',
        );
        expect(showToastSpy).not.toHaveBeenCalled();
        expect(captureException).toHaveBeenCalledWith({
          component: 'MavenRegistryDetailsApp',
          error: mockError,
        });
      });
    });
  });
});
