import { GlAlert, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { updateMavenUpstream } from 'ee/api/virtual_registries_api';
import RegistryUpstreamForm from 'ee/packages_and_registries/virtual_registries/components/maven/shared/registry_upstream_form.vue';
import MavenEditUpstreamApp from 'ee/packages_and_registries/virtual_registries/pages/maven/upstreams/edit.vue';
import DeleteUpstreamWithModal from 'ee/packages_and_registries/virtual_registries/components/maven/shared/delete_upstream_with_modal.vue';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';

jest.mock('ee/packages_and_registries/virtual_registries/sentry_utils');
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrlWithAlerts: jest.fn(),
}));

jest.mock('ee/api/virtual_registries_api', () => ({
  updateMavenUpstream: jest.fn(),
}));

describe('MavenEditUpstreamApp', () => {
  let wrapper;

  const defaultProvide = {
    upstream: {
      id: 1,
      name: 'Upstream',
      url: 'http://local.test/maven/',
      description: null,
      username: null,
      cacheValidityHours: 24,
    },
    upstreamsPath: '/groups/package-group/-/virtual_registries/maven?tab=upstreams',
    upstreamPath: '/groups/package-group/-/virtual_registries/maven/upstreams/3',
    glAbilities: {
      destroyVirtualRegistry: true,
    },
  };

  const findModal = () => wrapper.findComponent(DeleteUpstreamWithModal);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findDeleteUpstreamBtn = () => wrapper.findComponent(GlButton);
  const findForm = () => wrapper.findComponent(RegistryUpstreamForm);

  const mockError = new Error('API error');

  const createComponent = ({ provide } = {}) => {
    wrapper = shallowMountExtended(MavenEditUpstreamApp, {
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  beforeEach(() => {
    updateMavenUpstream.mockReset();
  });

  describe('render', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays registry form', () => {
      expect(findForm().exists()).toBe(true);
      expect(findForm().props('upstream')).toStrictEqual({
        id: 1,
        name: 'Upstream',
        url: 'http://local.test/maven/',
        description: null,
        username: null,
        cacheValidityHours: 24,
      });
    });

    it('sets correct props on DeleteUpstreamWithModal component', () => {
      expect(findModal().props()).toStrictEqual({
        upstreamId: 1,
        upstreamName: 'Upstream',
        visible: false,
      });
    });

    it('shows delete button', () => {
      expect(findDeleteUpstreamBtn().exists()).toBe(true);
    });

    describe('clicking on delete button', () => {
      it('sets modal to visible', async () => {
        await findDeleteUpstreamBtn().vm.$emit('click');

        expect(findModal().props('visible')).toBe(true);
      });
    });

    describe('without permission', () => {
      it('does not show delete button', () => {
        createComponent({
          provide: {
            glAbilities: {
              destroyVirtualRegistry: false,
            },
          },
        });

        expect(findDeleteUpstreamBtn().exists()).toBe(false);
      });
    });
  });

  describe('updating registry', () => {
    const formData = {
      name: 'New Upstream',
      url: 'http://local.test/maven/',
      description: 'description',
      username: null,
      cacheValidityHours: 24,
      metadataCacheValidityHours: 48,
    };

    it('calls updateUpstream API with correct ID', async () => {
      createComponent();

      await findForm().vm.$emit('submit', formData);

      const expectedData = {
        name: 'New Upstream',
        url: 'http://local.test/maven/',
        description: 'description',
        username: null,
        cache_validity_hours: 24,
        metadata_cache_validity_hours: 48,
      };
      expect(updateMavenUpstream).toHaveBeenCalledWith({ data: expectedData, id: 1 });
      expect(visitUrlWithAlerts).toHaveBeenCalledWith(
        '/groups/package-group/-/virtual_registries/maven/upstreams/3',
        [{ message: 'Maven upstream has been updated.' }],
      );
    });

    it('show parses error message on failure', async () => {
      updateMavenUpstream.mockRejectedValue({
        response: {
          status: 400,
          data: { message: { group: ['already has an upstream with the same credentials'] } },
        },
      });

      createComponent();

      expect(findAlert().exists()).toBe(false);

      findForm().vm.$emit('submit', formData);

      await waitForPromises();

      expect(findAlert().text()).toBe('group already has an upstream with the same credentials');
      expect(captureException).not.toHaveBeenCalled();
    });

    it('shows error alert on failure', async () => {
      updateMavenUpstream.mockRejectedValue(mockError);

      createComponent();

      expect(findAlert().exists()).toBe(false);

      findForm().vm.$emit('submit', formData);

      await waitForPromises();

      expect(findAlert().text()).toBe('API error');
      expect(captureException).toHaveBeenCalledWith({
        component: 'MavenEditUpstreamApp',
        error: mockError,
      });
    });
  });

  describe('deleting registry', () => {
    beforeEach(() => {
      createComponent();
      findDeleteUpstreamBtn().vm.$emit('click');
    });

    it('calls visitUrlWithAlerts when DeleteUpstreamWithModal emits success', () => {
      findModal().vm.$emit('success');

      expect(visitUrlWithAlerts).toHaveBeenCalledWith(
        '/groups/package-group/-/virtual_registries/maven?tab=upstreams',
        [{ message: 'Maven upstream has been deleted.' }],
      );
    });

    it('shows error alert when DeleteUpstreamWithModal emits error', async () => {
      expect(findAlert().exists()).toBe(false);

      await findModal().vm.$emit('error', mockError);

      expect(findAlert().text()).toBe('API error');
      expect(captureException).toHaveBeenCalledWith({
        component: 'MavenEditUpstreamApp',
        error: mockError,
      });
    });
  });
});
