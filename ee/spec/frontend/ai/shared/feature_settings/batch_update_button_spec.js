import { GlButton } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import BatchUpdateButton from 'ee/ai/shared/feature_settings/batch_update_button.vue';
import { DUO_MAIN_FEATURES } from 'ee/ai/duo_self_hosted/constants';

describe('BatchUpdateButton', () => {
  let wrapper;

  const mainFeature = DUO_MAIN_FEATURES.CODE_SUGGESTIONS;

  const createComponent = (props = {}) => {
    wrapper = mountExtended(BatchUpdateButton, {
      propsData: {
        mainFeature,
        ...props,
      },
    });
  };

  const findBatchUpdateButton = () => wrapper.findComponent(BatchUpdateButton);
  const findBatchUpdateButtonTooltip = () => wrapper.findByTestId('model-batch-assignment-tooltip');

  beforeEach(() => {
    createComponent();
  });

  it('renders the component', () => {
    expect(findBatchUpdateButton().props()).toMatchObject({
      mainFeature,
      disabled: false,
    });
  });

  it('displays a tooltip title', () => {
    expect(findBatchUpdateButtonTooltip().attributes('title')).toBe(
      'Apply to all Code Suggestions sub-features',
    );
  });

  describe('when the button is disabled', () => {
    beforeEach(() => {
      createComponent({ disabled: true });
    });

    it('displays a disabled tooltip', () => {
      expect(findBatchUpdateButtonTooltip().attributes('title')).toBe(
        'This model cannot be applied to all Code Suggestions sub-features',
      );
    });

    it('does not emit batch update event', () => {
      const button = findBatchUpdateButton().findComponent(GlButton);
      button.trigger('click');

      expect(wrapper.emitted('batch-update')).toBeUndefined();
    });
  });

  it('triggers onClick callback when the button is clicked', () => {
    const button = findBatchUpdateButton().findComponent(GlButton);
    button.trigger('click');

    expect(wrapper.emitted('batch-update')).toHaveLength(1);
  });
});
