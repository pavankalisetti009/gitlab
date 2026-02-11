import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox } from '@gitlab/ui';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import DuoExpandedLoggingForm from 'ee/ai/settings/components/duo_expanded_logging_form.vue';

describe('DuoExpandedLoggingForm', () => {
  let wrapper;

  const createComponent = ({ props = {}, injectedProps = {} } = {}) => {
    wrapper = extendedWrapper(
      shallowMount(DuoExpandedLoggingForm, {
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
    createComponent({ injectedProps: { enabledExpandedLogging: true } });
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

  describe('when expanded AI logs have been enabled', () => {
    beforeEach(() => {
      createComponent({ injectedProps: { enabledExpandedLogging: true } });
    });

    it('renders the checkbox checked', () => {
      expect(findCheckbox().props('checked')).toBe(true);
    });
  });

  describe('when expanded AI logs have not been enabled', () => {
    beforeEach(() => {
      createComponent({ injectedProps: { enabledExpandedLogging: false } });
    });

    it('renders the checkbox unchecked', () => {
      expect(findCheckbox().props('checked')).toBe(false);
    });
  });
});
