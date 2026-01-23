import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import RegistryForm from 'ee/packages_and_registries/virtual_registries/components/registry/form.vue';
import createRegistryMutation from 'ee/packages_and_registries/virtual_registries/graphql/mutations/create_container_registry.mutation.graphql';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';

jest.mock('ee/packages_and_registries/virtual_registries/sentry_utils');

Vue.use(VueApollo);

describe('Virtual registry form component', () => {
  let wrapper;

  const createMutationHandler = jest.fn().mockResolvedValue({
    data: {
      createRegistry: {
        errors: [],
        registry: {
          id: 1,
          name: 'Registry name',
          description: 'Registry description',
        },
      },
    },
  });
  const routerPushMock = jest.fn();

  const findFormFields = () => wrapper.findByTestId('registry-form');
  const findErrorMessages = () => wrapper.findAllByTestId('registry-error-message');

  function factory(handler = createMutationHandler) {
    const apolloProvider = createMockApollo([[createRegistryMutation, handler]]);

    wrapper = mountExtended(RegistryForm, {
      apolloProvider,
      provide: {
        fullPath: 'gitlab-org',
        createRegistryMutation,
      },
      stubs: {
        RouterLink: true,
      },
      mocks: {
        $router: {
          push: routerPushMock,
        },
      },
    });
  }

  it('renders form fields with name and description in fields prop', () => {
    factory();

    expect(findFormFields().props('fields')).toEqual(
      expect.objectContaining({
        name: expect.any(Object),
        description: expect.any(Object),
      }),
    );
  });

  describe('when create mutation is submitted', () => {
    it('sends registry data on submit', async () => {
      factory();

      findFormFields().vm.$emit('input', {
        name: 'Registry name',
        description: 'Registry description',
      });
      findFormFields().vm.$emit('submit');

      await waitForPromises();

      expect(createMutationHandler).toHaveBeenCalledWith({
        input: {
          description: 'Registry description',
          name: 'Registry name',
          groupPath: 'gitlab-org',
        },
      });
    });

    it('pushes new route', async () => {
      factory();

      findFormFields().vm.$emit('input', {
        name: 'Registry name',
        description: 'Registry description',
      });
      findFormFields().vm.$emit('submit');

      await waitForPromises();

      expect(routerPushMock).toHaveBeenCalledWith({
        params: {
          id: 1,
        },
        name: expect.any(String),
      });
    });

    describe('when mutation returns error', () => {
      it('renders error message', async () => {
        const errorHandler = jest.fn().mockResolvedValue({
          data: {
            createRegistry: {
              errors: ['Error!', 'Another error'],
              registry: null,
            },
          },
        });

        factory(errorHandler);

        findFormFields().vm.$emit('submit');

        await waitForPromises();

        expect(findErrorMessages()).toHaveLength(2);
        expect(findErrorMessages().at(0).text()).toBe('Error!');
        expect(findErrorMessages().at(1).text()).toBe('Another error');
      });
    });

    describe('when server returns error', () => {
      beforeEach(() => {
        const errorHandler = jest.fn().mockRejectedValue({
          data: {
            createRegistry: {
              errors: [],
              registry: null,
            },
          },
        });

        factory(errorHandler);
      });

      it('renders error message', async () => {
        findFormFields().vm.$emit('submit');

        await waitForPromises();

        expect(findErrorMessages()).toHaveLength(1);
        expect(findErrorMessages().at(0).text()).toBe('Something went wrong. Please try again.');
      });

      it('captures exception', async () => {
        findFormFields().vm.$emit('submit');

        await waitForPromises();

        expect(captureException).toHaveBeenCalledWith({
          component: 'RegistryForm',
          error: expect.anything(),
        });
      });
    });
  });
});
