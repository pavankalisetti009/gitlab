import { shallowMount } from '@vue/test-utils';
import SelfHostedModelForm from 'ee/pages/admin/ai/self_hosted_models/components/self_hosted_model_form.vue';
import createSelfHostedModelMutation from 'ee/pages/admin/ai/self_hosted_models/graphql/mutations/create_self_hosted_model.mutation.graphql';
import NewSelfHostedModel from 'ee/pages/admin/ai/self_hosted_models/components/new_self_hosted_model.vue';
import { SELF_HOSTED_MODEL_MUTATIONS } from 'ee/pages/admin/ai/self_hosted_models/constants';
import { SELF_HOSTED_MODEL_OPTIONS } from './mock_data';

describe('NewSelfHostedModel', () => {
  let wrapper;

  const basePath = '/admin/ai/self_hosted_models';

  const createComponent = () => {
    wrapper = shallowMount(NewSelfHostedModel, {
      propsData: {
        basePath,
        modelOptions: SELF_HOSTED_MODEL_OPTIONS,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  const findSelfHostedModelForm = () => wrapper.findComponent(SelfHostedModelForm);

  it('has a title', () => {
    expect(wrapper.text()).toMatch('Add self-hosted models');
  });

  it('has a description', () => {
    expect(wrapper.text()).toMatch('Add a new AI model that can be used for GitLab Duo features.');
  });

  it('renders the self-hosted model form and passes the correct props', () => {
    const selfHostedModelForm = findSelfHostedModelForm();

    expect(selfHostedModelForm.exists()).toBe(true);
    expect(selfHostedModelForm.props('basePath')).toBe(basePath);
    expect(selfHostedModelForm.props('modelOptions')).toBe(SELF_HOSTED_MODEL_OPTIONS);
    expect(selfHostedModelForm.props('mutationData')).toEqual({
      name: SELF_HOSTED_MODEL_MUTATIONS.CREATE,
      mutation: createSelfHostedModelMutation,
    });
  });
});
