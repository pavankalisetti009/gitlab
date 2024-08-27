import ValueStreamFormContentHeader from 'ee/analytics/cycle_analytics/vsa_settings/components/value_stream_form_content_header.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { valueStreamPath } from '../../mock_data';

describe('ValueStreamFormContentHeader', () => {
  let wrapper;

  const findPrimaryActionBtn = () => wrapper.findByTestId('value-stream-form-primary-btn');
  const findFormTitle = () => wrapper.findByTestId('value-stream-form-title');
  const findViewValueStreamBtn = () => wrapper.findByTestId('view-value-stream');

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(ValueStreamFormContentHeader, {
      propsData: {
        valueStreamPath,
        ...props,
      },
    });
  };

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the correct form title', () => {
      expect(findFormTitle().text()).toBe('New value stream');
    });

    it('renders new value stream button', () => {
      expect(findPrimaryActionBtn().text()).toBe('New value stream');
    });

    it('emits `clickedPrimaryAction` event when create button is clicked', () => {
      findPrimaryActionBtn().vm.$emit('click');

      expect(wrapper.emitted('clickedPrimaryAction')).toHaveLength(1);
    });

    it('does not render view value stream button link', () => {
      expect(findViewValueStreamBtn().exists()).toBe(false);
    });

    it('does not set new value stream to a loading state', () => {
      expect(findPrimaryActionBtn().props('loading')).toBe(false);
    });

    describe('isLoading=true', () => {
      beforeEach(() => {
        createComponent({ props: { isLoading: true } });
      });

      it('sets the create button to a loading state', () => {
        expect(findPrimaryActionBtn().props('loading')).toBe(true);
      });
    });
  });

  describe('isEditing=true', () => {
    beforeEach(() => {
      createComponent({ props: { isEditing: true } });
    });

    it('renders the correct form title', () => {
      expect(findFormTitle().text()).toBe('Edit value stream');
    });

    it('renders save button', () => {
      expect(findPrimaryActionBtn().text()).toBe('Save value stream');
    });

    it('renders view value stream button link', () => {
      expect(findViewValueStreamBtn().attributes('href')).toBe(valueStreamPath);
    });

    it('emits `clickedPrimaryAction` event when save button is clicked', () => {
      findPrimaryActionBtn().vm.$emit('click');

      expect(wrapper.emitted('clickedPrimaryAction')).toHaveLength(1);
    });

    it('does not set save button to a loading state', () => {
      expect(findPrimaryActionBtn().props('loading')).toBe(false);
    });

    describe('isLoading=true', () => {
      beforeEach(() => {
        createComponent({ props: { isLoading: true, isEditing: true } });
      });

      it('sets the save button to a loading state', () => {
        expect(findPrimaryActionBtn().props('loading')).toBe(true);
      });

      it('disables the view value stream button link', () => {
        expect(findViewValueStreamBtn().props('disabled')).toBe(true);
      });
    });
  });
});
