import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox } from '@gitlab/ui';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import AiUsageDataCollectionForm from 'ee/ai/settings/components/ai_usage_data_collection_form.vue';

describe('AiUsageDataCollectionForm', () => {
  let wrapper;

  const createComponent = ({ props = {}, injectedProps = {} } = {}) => {
    wrapper = extendedWrapper(
      shallowMount(AiUsageDataCollectionForm, {
        provide: {
          ...injectedProps,
        },
        propsData: {
          ...props,
        },
        stubs: {
          GlFormCheckbox,
        },
      }),
    );
  };

  beforeEach(() => {
    createComponent({ injectedProps: { aiUsageDataCollectionEnabled: true } });
  });

  const findTitle = () => wrapper.find('h5').text();
  const findCheckbox = () => wrapper.findComponent(GlFormCheckbox);

  it('has the correct title', () => {
    expect(findTitle()).toBe('Data collection');
  });

  it('has the correct label', () => {
    expect(findCheckbox().find('span').text()).toBe('Collect usage data');
  });

  it('has the correct help text', () => {
    expect(findCheckbox().text()).toContain(
      'Allow GitLab to collect prompts, AI responses, and metadata from user interactions with GitLab Duo. This data helps to improve service quality and is not used to train models.',
    );
  });

  it.each`
    aiUsageDataCollectionEnabled | description
    ${true}                      | ${'checked'}
    ${false}                     | ${'unchecked'}
  `(
    'renders the checkbox as $description when aiUsageDataCollectionEnabled is set to $aiUsageDataCollectionEnabled',
    ({ aiUsageDataCollectionEnabled }) => {
      createComponent({ injectedProps: { aiUsageDataCollectionEnabled } });

      expect(findCheckbox().props('checked')).toBe(aiUsageDataCollectionEnabled);
    },
  );
});
