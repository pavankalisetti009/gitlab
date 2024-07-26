import { mountExtended } from 'helpers/vue_test_utils_helper';
import NewSelfHostedModel from 'ee/pages/admin/ai/self_hosted_models/components/new_self_hosted_model.vue';
import { SELF_HOSTED_MODEL_OPTIONS } from './mock_data';

describe('NewSelfHostedModel', () => {
  let wrapper;

  const basePath = '/admin/ai/self_hosted_models';

  const createComponent = () => {
    wrapper = mountExtended(NewSelfHostedModel, {
      propsData: {
        basePath,
        modelOptions: SELF_HOSTED_MODEL_OPTIONS,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('has a title', () => {
    expect(wrapper.text()).toMatch('Add self-hosted models');
  });

  it('has a description', () => {
    expect(wrapper.text()).toMatch('Add a new AI model that can be used for GitLab Duo features.');
  });
});
