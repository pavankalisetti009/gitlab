import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlModal, GlButton, GlSprintf, GlDisclosureDropdownItem } from '@gitlab/ui';
import { shallowMount, createWrapper } from '@vue/test-utils';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { BV_SHOW_MODAL } from '~/lib/utils/constants';
import { createAlert } from '~/alert';
import deleteSelfHostedModelMutation from 'ee/pages/admin/ai/self_hosted_models/graphql/mutations/delete_self_hosted_model.mutation.graphql';
import getSelfHostedModelsQuery from 'ee/pages/admin/ai/self_hosted_models/graphql/queries/get_self_hosted_models.query.graphql';
import DeleteSelfHostedModelDisclosureItem from 'ee/pages/admin/ai/self_hosted_models/components/delete_self_hosted_model_disclosure_item.vue';
import { mockSelfHostedModel } from './mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('DeleteSelfHostedModelDisclosureItem', () => {
  let wrapper;

  const modelToDelete = mockSelfHostedModel;

  const deleteMutationSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiSelfHostedModelDelete: {
        errors: [],
      },
    },
  });

  const getSelfHostedModelsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiSelfHostedModels: {
        errors: [],
      },
    },
  });

  const createComponent = ({
    apolloHandlers = [[deleteSelfHostedModelMutation, deleteMutationSuccessHandler]],
    props = {},
  } = {}) => {
    const mockApollo = createMockApollo([
      [getSelfHostedModelsQuery, getSelfHostedModelsSuccessHandler],
      ...apolloHandlers,
    ]);

    wrapper = extendedWrapper(
      shallowMount(DeleteSelfHostedModelDisclosureItem, {
        apolloProvider: mockApollo,
        propsData: {
          model: modelToDelete,
          ...props,
        },
        stubs: { GlModal, GlButton, GlSprintf },
      }),
    );
  };

  beforeEach(() => {
    createComponent();
  });

  const findModal = () => wrapper.findComponent(GlModal);
  const findDisclosureDeleteButton = () => wrapper.findComponent(GlDisclosureDropdownItem);
  const findModalText = () => wrapper.findByTestId('delete-model-confirmation-message').text();
  const findCancelButton = () => wrapper.findAllComponents(GlButton).at(0);
  const findDeleteButton = () => wrapper.findAllComponents(GlButton).at(1);

  it('renders the disclosure delete button', () => {
    expect(findDisclosureDeleteButton().text()).toBe('Delete');
  });

  it('renders the modal', () => {
    expect(findModal().exists()).toBe(true);
  });

  it('opens the modal when the disclosure button is clicked', async () => {
    await findDisclosureDeleteButton().trigger('click');

    expect(createWrapper(wrapper.vm.$root).emitted(BV_SHOW_MODAL)).toHaveLength(1);
  });

  describe('modal', () => {
    it('displays the correct title', () => {
      expect(findModal().props('title')).toBe('Delete self-hosted model');
    });

    it('displays the correct body', () => {
      expect(findModalText()).toMatchInterpolatedText(
        `You are about to delete the ${mockSelfHostedModel.name} self-hosted model. This action cannot be undone.`,
      );
    });

    it('has a cancel button', () => {
      expect(findCancelButton().text()).toBe('Cancel');
    });

    describe('deleting a self-hosted model', () => {
      it('renders the button', () => {
        expect(findDeleteButton().text()).toBe('Delete');
      });

      it('invokes delete mutation', () => {
        findModal().vm.$emit('primary');

        expect(deleteMutationSuccessHandler).toHaveBeenCalledWith({
          input: { id: modelToDelete.id },
        });
      });

      describe('when a deletion succeeds', () => {
        beforeEach(async () => {
          createComponent();

          findModal().vm.$emit('primary');

          await waitForPromises();
        });

        it('refreshes self-hosted model data', () => {
          expect(getSelfHostedModelsSuccessHandler).toHaveBeenCalled();
        });

        it('shows a success message', () => {
          expect(createAlert).toHaveBeenCalledWith(
            expect.objectContaining({
              message: 'Your self-hosted model was successfully deleted.',
            }),
          );
        });
      });

      describe('when a deletion fails', () => {
        const deleteMutationErrorHandler = jest.fn().mockResolvedValue({
          data: {
            aiSelfHostedModelDelete: {
              errors: ['Self-hosted model not found'],
            },
          },
        });

        beforeEach(() => {
          createComponent({
            apolloHandlers: [[deleteSelfHostedModelMutation, deleteMutationErrorHandler]],
          });
        });

        it('shows an error message', async () => {
          findModal().vm.$emit('primary');

          await waitForPromises();

          expect(createAlert).toHaveBeenCalledWith(
            expect.objectContaining({
              message: 'Self-hosted model not found',
            }),
          );
        });
      });
    });
  });
});
