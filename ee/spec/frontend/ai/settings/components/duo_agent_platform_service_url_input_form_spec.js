import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlFormGroup, GlFormInput, GlSprintf } from '@gitlab/ui';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import DuoAgentPlatformServiceUrlInputForm from 'ee/ai/settings/components/duo_agent_platform_service_url_input_form.vue';

let wrapper;

const duoAgentPlatformServiceUrl = 'localhost:50052';
const createComponent = ({ injectedProps = {} } = {}) => {
  wrapper = extendedWrapper(
    shallowMount(DuoAgentPlatformServiceUrlInputForm, {
      provide: {
        duoAgentPlatformServiceUrl,
        ...injectedProps,
      },
      stubs: {
        GlFormGroup,
        GlSprintf,
      },
    }),
  );
};

const findDuoAgentPlatformServiceUrlInputForm = () =>
  wrapper.findComponent(DuoAgentPlatformServiceUrlInputForm);
const findFormInput = () => wrapper.findComponent(GlFormInput);
const findLabelDescription = () => wrapper.findByTestId('label-description');

describe('DuoAgentPlatformServiceUrlInputForm', () => {
  beforeEach(() => {
    createComponent();
  });

  it('renders the component', () => {
    expect(findDuoAgentPlatformServiceUrlInputForm().exists()).toBe(true);
  });

  it('has the correct label', () => {
    expect(findDuoAgentPlatformServiceUrlInputForm().attributes('label')).toEqual(
      'Local URL for the GitLab Duo Agent Platform service',
    );
  });

  it('has the correct label description', () => {
    expect(findLabelDescription().text()).toMatch(
      'Enter the URL for your Duo Agent Platform service',
    );
  });

  describe('form input', () => {
    it('renders the correct value', () => {
      expect(findFormInput().attributes('value')).toEqual(duoAgentPlatformServiceUrl);
    });

    it('emits a change event when updated', async () => {
      const newDuoAgentPlatformServiceUrl = 'new-duo-agent-platform-url:50052';
      findFormInput().vm.$emit('input', newDuoAgentPlatformServiceUrl);

      await nextTick();

      findFormInput().vm.$emit('update', newDuoAgentPlatformServiceUrl);

      expect(findFormInput().attributes('value')).toBe(newDuoAgentPlatformServiceUrl);
      expect(wrapper.emitted('change')).toEqual([[newDuoAgentPlatformServiceUrl]]);
    });
  });
});
