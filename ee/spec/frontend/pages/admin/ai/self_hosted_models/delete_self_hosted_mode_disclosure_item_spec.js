import { GlModal, GlButton, GlSprintf, GlDisclosureDropdownItem } from '@gitlab/ui';
import { shallowMount, createWrapper } from '@vue/test-utils';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import { BV_SHOW_MODAL } from '~/lib/utils/constants';
import DeleteSelfHostedModelDisclosureItem from 'ee/pages/admin/ai/self_hosted_models/components/delete_self_hosted_model_disclosure_item.vue';
import { mockSelfHostedModel } from './mock_data';

describe('DeleteSelfHostedModelDisclosureItem', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = extendedWrapper(
      shallowMount(DeleteSelfHostedModelDisclosureItem, {
        propsData: {
          model: mockSelfHostedModel,
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

    it('has a delete button', () => {
      expect(findDeleteButton().text()).toBe('Delete');
    });

    it('has a cancel button', () => {
      expect(findCancelButton().text()).toBe('Cancel');
    });
  });
});
