import { shallowMount } from '@vue/test-utils';
import FeatureSettingsApp from 'ee/pages/admin/ai/feature_settings/components/app.vue';

describe('FeatureSettingsApp', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(FeatureSettingsApp);
  };

  beforeEach(() => {
    createComponent();
  });

  it('has a title', () => {
    const title = wrapper.find('h1');

    expect(title.text()).toBe('AI-powered features');
  });

  it('has a description', () => {
    expect(wrapper.text()).toMatch(
      'Features that can be enabled, disabled, or linked to a cloud-based or self-hosted model.',
    );
  });
});
