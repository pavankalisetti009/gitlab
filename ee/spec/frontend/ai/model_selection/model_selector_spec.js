import Vue, { nextTick } from 'vue';
import { GlToast } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import ModelSelector from 'ee/ai/model_selection/model_selector.vue';
import ModelSelectDropdown from 'ee/ai/shared/feature_settings/model_select_dropdown.vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import { mockDuoChatFeatureSettings } from '../shared/feature_settings/mock_data';

Vue.use(GlToast);

describe('ModelSelector', () => {
  let wrapper;

  const createComponent = ({ props = {} } = {}) => {
    wrapper = extendedWrapper(
      shallowMount(ModelSelector, {
        propsData: {
          aiFeatureSetting: mockDuoChatFeatureSettings[0],
          ...props,
        },
        mocks: {
          $toast: {
            show: jest.fn(),
          },
        },
      }),
    );
  };

  const findModelSelector = () => wrapper.findComponent(ModelSelector);
  const findModelSelectDropdown = () => wrapper.findComponent(ModelSelectDropdown);
  const findDropdownToggleText = () => findModelSelectDropdown().props('dropdownToggleText');

  it('renders the component', () => {
    createComponent();

    expect(findModelSelector().exists()).toBe(true);
  });

  describe('.listItems', () => {
    it('contains a list of models, including a default model option', () => {
      createComponent();

      expect(findModelSelectDropdown().props('items')).toEqual([
        { value: 'claude_sonnet_3_7_20250219', text: 'Claude Sonnet 3.7 - Anthropic' },
        { value: 'claude_3_5_sonnet_20240620', text: 'Claude Sonnet 3.5 - Anthropic' },
        { value: 'claude_3_haiku_20240307', text: 'Claude Haiku 3 - Anthropic' },
        { value: 'gitlab', text: 'GitLab Default' },
      ]);
    });
  });

  describe('updating the feature setting', () => {
    beforeEach(() => {
      createComponent();
    });

    it('triggers a success toast', () => {
      findModelSelectDropdown().vm.$emit('select', 1);

      expect(wrapper.vm.$toast.show).toHaveBeenCalledWith(
        'Successfully updated GitLab Duo Chat / General Chat',
      );
    });

    describe('when the feature state is changed', () => {
      it('updates the dropdown toggle text', async () => {
        expect(findDropdownToggleText()).toBe('Claude Sonnet 3.7 - Anthropic');

        findModelSelectDropdown().vm.$emit('select', 'gitlab');

        await nextTick();

        expect(findDropdownToggleText()).toBe('GitLab Default');
      });
    });
  });
});
