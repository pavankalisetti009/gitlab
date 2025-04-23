import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlFormInput, GlModal, GlSprintf } from '@gitlab/ui';
import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { INDEX_ROUTE_NAME } from 'ee/ci/secrets/constants';
import deleteSecretMutation from 'ee/ci/secrets/graphql/mutations/delete_secret.mutation.graphql';
import SecretDeleteModal from 'ee/ci/secrets/components/secret_delete_modal.vue';
import {
  mockDeleteProjectSecretResponse,
  mockDeleteProjectSecretErrorResponse,
} from '../mock_data';

jest.mock('~/alert');
Vue.use(VueApollo);

describe('SecretDetailsWrapper component', () => {
  let wrapper;
  let mockApollo;
  let mockDeleteSecretMutationResponse;

  const mockRouter = {
    push: jest.fn(),
  };

  const defaultProps = {
    fullPath: 'path/to/project',
    secretName: 'SECRET_KEY',
    showModal: true,
  };

  const createComponent = ({ props = {}, stubs = { GlSprintf } } = {}) => {
    mockApollo = createMockApollo([[deleteSecretMutation, mockDeleteSecretMutationResponse]]);

    wrapper = shallowMountExtended(SecretDeleteModal, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        RouterView: true,
        ...stubs,
      },
      mocks: {
        $router: mockRouter,
        $route: { name: INDEX_ROUTE_NAME },
      },
    });
  };

  const findInput = () => wrapper.findComponent(GlFormInput);
  const findModal = () => wrapper.findComponent(GlModal);
  const findModalDescription = () => wrapper.findByTestId('secret-delete-modal-description');
  const findModalConfirmText = () => wrapper.findByTestId('secret-delete-modal-confirm-text');
  const findDeleteButton = () => findModal().props('actionPrimary');

  const deleteSecret = async () => {
    findModal().vm.$emit('primary', { preventDefault: jest.fn() });
    await waitForPromises();
  };

  beforeEach(() => {
    mockDeleteSecretMutationResponse = jest.fn();
    mockDeleteSecretMutationResponse.mockResolvedValue(mockDeleteProjectSecretResponse);
  });

  describe('template', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('renders secret name in the modal text', () => {
      expect(findModalDescription().text()).toContain(
        'Are you sure you want to delete secret SECRET_KEY?',
      );
      expect(findModalConfirmText().text()).toBe('To confirm, enter SECRET_KEY:');
    });

    it('enables delete button when secret name is provided', async () => {
      expect(findDeleteButton().attributes.disabled).toBe(true);

      findInput().vm.$emit('input', 'SECRET_KEY');
      await nextTick();

      expect(findDeleteButton().attributes.disabled).toBe(false);
    });

    it('does not enable delete button when input does not match secret name', async () => {
      expect(findDeleteButton().attributes.disabled).toBe(true);

      findInput().vm.$emit('input', 'SECRET KEY');
      await nextTick();

      expect(findDeleteButton().attributes.disabled).toBe(true);
    });

    it.each`
      modalEvent     | emittedEvent
      ${'canceled'}  | ${'hide'}
      ${'hidden'}    | ${'hide'}
      ${'secondary'} | ${'hide'}
    `(
      'emits the $emittedEvent event when $modalEvent event is triggered',
      ({ modalEvent, emittedEvent }) => {
        expect(wrapper.emitted(emittedEvent)).toBeUndefined();

        findModal().vm.$emit(modalEvent);

        expect(wrapper.emitted(emittedEvent)).toHaveLength(1);
      },
    );
  });

  describe('when delete action succeeds', () => {
    beforeEach(async () => {
      await createComponent();
      await deleteSecret();
    });

    it('redirects to index page', () => {
      expect(mockRouter.push).toHaveBeenCalledWith({ name: INDEX_ROUTE_NAME });
    });

    it('triggers toast message', () => {
      expect(wrapper.emitted('show-secrets-toast')).toEqual([
        ['Secret SECRET_KEY has been deleted.'],
      ]);
    });
  });

  describe('when delete action fails', () => {
    beforeEach(async () => {
      mockDeleteSecretMutationResponse.mockResolvedValue(mockDeleteProjectSecretErrorResponse);
      await createComponent();
      await deleteSecret();
    });

    it('shows error in alert', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'This is an API error.',
      });
    });

    it('hides modal', () => {
      expect(wrapper.emitted('hide')).toHaveLength(1);
    });

    it('does not redirect to the index page', () => {
      expect(mockRouter.push).toHaveBeenCalledTimes(0);
    });
  });
});
