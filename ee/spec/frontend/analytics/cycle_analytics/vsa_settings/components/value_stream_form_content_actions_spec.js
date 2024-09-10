import ValueStreamFormContentHeader from 'ee/analytics/cycle_analytics/vsa_settings/components/value_stream_form_content_actions.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { valueStreamPath } from '../../mock_data';

describe('ValueStreamFormContentActions', () => {
  let wrapper;

  const findNewValueStreamBtn = () => wrapper.findByText('New value stream');
  const findSaveValueStreamBtn = () => wrapper.findByText('Save value stream');
  const findValueStreamCancelBtn = () => wrapper.findByText('Cancel');
  const findAddStageBtn = () => wrapper.findByText('Add a stage');

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(ValueStreamFormContentHeader, {
      propsData: {
        valueStreamPath,
        ...props,
      },
    });
  };

  describe.each`
    isEditing | findPrimaryActionBtn
    ${false}  | ${findNewValueStreamBtn}
    ${true}   | ${findSaveValueStreamBtn}
  `('when `isEditing` is `$isEditing`', ({ isEditing, findPrimaryActionBtn }) => {
    beforeEach(() => {
      createComponent({ props: { isEditing } });
    });

    it('renders primary action correctly', () => {
      expect(findPrimaryActionBtn().props()).toMatchObject({
        variant: 'confirm',
        loading: false,
        disabled: false,
      });
    });

    it('emits `clickPrimaryAction` event when primary action is selected', () => {
      findPrimaryActionBtn().vm.$emit('click');

      expect(wrapper.emitted('clickPrimaryAction')).toHaveLength(1);
    });

    it('renders add stage action correctly', () => {
      expect(findAddStageBtn().props()).toMatchObject({
        category: 'secondary',
        variant: 'confirm',
        disabled: false,
      });
    });

    it('emits `clickAddStageAction` event when add stage action is selected', () => {
      findAddStageBtn().vm.$emit('click');

      expect(wrapper.emitted('clickAddStageAction')).toHaveLength(1);
    });

    it('renders cancel button link correctly', () => {
      expect(findValueStreamCancelBtn().props('disabled')).toBe(false);
      expect(findValueStreamCancelBtn().attributes('href')).toBe(valueStreamPath);
    });

    describe('isLoading=true', () => {
      beforeEach(() => {
        createComponent({ props: { isEditing, isLoading: true } });
      });

      it('sets primary action to a loading state', () => {
        expect(findPrimaryActionBtn().props('loading')).toBe(true);
      });

      it('disables all other actions', () => {
        expect(findAddStageBtn().props('disabled')).toBe(true);
        expect(findValueStreamCancelBtn().props('disabled')).toBe(true);
      });
    });
  });
});
