import { shallowMount } from '@vue/test-utils';
import SelfHostedModelForm from 'ee/pages/admin/ai/self_hosted_models/components/self_hosted_model_form.vue';
import updateSelfHostedModelMutation from 'ee/pages/admin/ai/self_hosted_models/graphql/mutations/update_self_hosted_model.mutation.graphql';
import EditSelfHostedModel from 'ee/pages/admin/ai/self_hosted_models/components/edit_self_hosted_model.vue';
import { SELF_HOSTED_MODEL_MUTATIONS } from 'ee/pages/admin/ai/self_hosted_models/constants';
import { SELF_HOSTED_MODEL_OPTIONS, mockSelfHostedModel } from './mock_data';

describe('EditSelfHostedModel', () => {
  let wrapper;

  const basePath = '/admin/ai/self_hosted_models';

  const createComponent = ({ props = {} }) => {
    wrapper = shallowMount(EditSelfHostedModel, {
      propsData: {
        basePath,
        ...props,
      },
    });
  };

  beforeEach(() => {
    createComponent({
      props: { modelOptions: SELF_HOSTED_MODEL_OPTIONS, model: mockSelfHostedModel },
    });
  });

  const findSelfHostedModelForm = () => wrapper.findComponent(SelfHostedModelForm);

  it('has a title', () => {
    expect(wrapper.text()).toMatch('Edit self-hosted model');
  });

  it('has a description', () => {
    expect(wrapper.text()).toMatch('Edit the AI model that can be used for GitLab Duo features.');
  });

  it('renders the self-hosted model form and passes the correct props', () => {
    const selfHostedModelForm = findSelfHostedModelForm();

    expect(selfHostedModelForm.exists()).toBe(true);
    expect(selfHostedModelForm.props('basePath')).toBe(basePath);
    expect(selfHostedModelForm.props('initialFormValues')).toEqual(mockSelfHostedModel);
    expect(selfHostedModelForm.props('modelOptions')).toBe(SELF_HOSTED_MODEL_OPTIONS);
    expect(selfHostedModelForm.props('mutationData')).toEqual({
      name: SELF_HOSTED_MODEL_MUTATIONS.UPDATE,
      mutation: updateSelfHostedModelMutation,
    });
    expect(selfHostedModelForm.props('submitButtonText')).toBe('Edit self-hosted model');
  });
});
