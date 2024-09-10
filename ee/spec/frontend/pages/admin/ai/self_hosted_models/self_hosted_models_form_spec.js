import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlForm, GlCollapsibleListbox } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import SelfHostedModelForm from 'ee/pages/admin/ai/self_hosted_models/components/self_hosted_model_form.vue';
import createSelfHostedModelMutation from 'ee/pages/admin/ai/self_hosted_models/graphql/mutations/create_self_hosted_model.mutation.graphql';
import { createAlert } from '~/alert';
import { SELF_HOSTED_MODEL_OPTIONS } from './mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('SelfHostedModelForm', () => {
  let wrapper;

  const createMutationSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiSelfHostedModelCreate: {
        errors: [],
      },
    },
  });

  const createComponent = async ({
    apolloHandlers = [[createSelfHostedModelMutation, createMutationSuccessHandler]],
  } = {}) => {
    const mockApollo = createMockApollo([...apolloHandlers]);
    const basePath = '/admin/ai/self_hosted_models';

    wrapper = mountExtended(SelfHostedModelForm, {
      apolloProvider: mockApollo,
      propsData: {
        basePath,
        modelOptions: SELF_HOSTED_MODEL_OPTIONS,
        mutationData: {
          name: 'aiSelfHostedModelCreate',
          mutation: createSelfHostedModelMutation,
        },
      },
    });

    await waitForPromises();
  };

  beforeEach(async () => {
    await createComponent();
  });

  const findGlForm = () => wrapper.findComponent(GlForm);
  const findNameInputField = () => wrapper.findByLabelText('Deployment name');
  const findEndpointInputField = () => wrapper.findByLabelText('Endpoint');
  const findApiKeyInputField = () => wrapper.findByLabelText('API Key (optional)');
  const findCollapsibleListBox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findCreateButton = () => wrapper.find('button[type="submit"]');
  const findCancelButton = () => wrapper.findByText('Cancel');

  it('renders the self-hosted model details form', () => {
    expect(findGlForm().exists()).toBe(true);
  });

  describe('form fields', () => {
    it('renders the name input field', () => {
      expect(findNameInputField().exists()).toBe(true);
    });

    it('renders a model dropdown selector with model options', () => {
      const modelDropdownSelector = findCollapsibleListBox();

      expect(modelDropdownSelector.props('toggleText')).toEqual('Select model');

      const modelOptions = modelDropdownSelector.props('items');
      expect(modelOptions.map((model) => model.text)).toEqual([
        'CodeGemma 2b',
        'CodeGemma 7b-it',
        'CodeGemma 7b',
        'Code-Llama 13b-code',
        'Code-Llama 13b',
        'Codestral 22B',
        'Mistral 7B',
        'Mixtral 8x22B',
        'Mixtral 8x7B',
        'DEEPSEEKCODER',
        'Mistral Text 7B',
        'Mixtral Text 8x7B',
        'Mixtral Text 8X22B',
      ]);
    });

    it('renders the endpoint input field', () => {
      expect(findEndpointInputField().exists()).toBe(true);
    });

    it('renders the optional API token input field', () => {
      expect(findApiKeyInputField().exists()).toBe(true);
    });
  });

  it('renders a create button', () => {
    const button = findCreateButton();

    expect(button.text()).toBe('Create self-hosted model');
  });

  it('renders a cancel button', () => {
    expect(findCancelButton().exists()).toBe(true);
  });

  describe('when required form inputs are missing', () => {
    it('does not invoke mutation', async () => {
      wrapper.find('form').trigger('submit.prevent');

      await waitForPromises();

      expect(createMutationSuccessHandler).not.toHaveBeenCalled();
    });
  });

  describe('server errors', () => {
    describe('when deployment name is not unique', () => {
      const createMutationValidationErrorHandler = jest.fn().mockResolvedValue({
        data: {
          aiSelfHostedModelCreate: {
            errors: ['Validation failed: Name has already been taken'],
          },
        },
      });
      const apolloHandlers = [
        [createSelfHostedModelMutation, createMutationValidationErrorHandler],
      ];

      beforeEach(async () => {
        await createComponent({ apolloHandlers });
      });

      it('renders an error message', async () => {
        await findNameInputField().setValue('test deployment');
        await findEndpointInputField().setValue('http://test.com');
        await findCollapsibleListBox().vm.$emit('select', 'MIXTRAL');

        wrapper.find('form').trigger('submit.prevent');

        await waitForPromises();

        expect(wrapper.text()).toMatch('Please enter a unique deployment name.');
      });
    });

    describe('when endpoint is not valid', () => {
      const createMutationValidationErrorHandler = jest.fn().mockResolvedValue({
        data: {
          aiSelfHostedModelCreate: {
            errors: [
              'Validation failed: Endpoint is blocked: Only allowed schemes are http, https',
            ],
          },
        },
      });
      const apolloHandlers = [
        [createSelfHostedModelMutation, createMutationValidationErrorHandler],
      ];

      beforeEach(async () => {
        await createComponent({ apolloHandlers });
      });

      it('renders an error message', async () => {
        await findNameInputField().setValue('test deployment');
        await findEndpointInputField().setValue('invalid endpoint');
        await findCollapsibleListBox().vm.$emit('select', 'MIXTRAL');

        wrapper.find('form').trigger('submit.prevent');

        await waitForPromises();

        expect(wrapper.text()).toMatch('Please add a valid endpoint.');
      });
    });

    describe('when the error is not specific', () => {
      it('displays a generic error alert', async () => {
        const error = new Error();
        const createMutationErrorHandler = jest.fn().mockRejectedValue(error);

        await createComponent({
          apolloHandlers: [[createSelfHostedModelMutation, createMutationErrorHandler]],
        });

        await findNameInputField().setValue('test deployment');
        await findEndpointInputField().setValue('http://test.com');
        await findCollapsibleListBox().vm.$emit('select', 'MIXTRAL');

        wrapper.find('form').trigger('submit.prevent');

        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'There was an error creating the self-hosted model. Please try again.',
            error,
            captureError: true,
          }),
        );
      });
    });
  });
});
