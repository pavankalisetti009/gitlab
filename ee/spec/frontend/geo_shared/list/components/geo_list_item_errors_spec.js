import { GlCollapse, GlButton } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoListItemErrors from 'ee/geo_shared/list/components/geo_list_item_errors.vue';
import { MOCK_ERRORS } from '../mock_data';

describe('GeoListItemErrors', () => {
  let wrapper;

  const defaultProps = {
    errorsArray: MOCK_ERRORS,
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(GeoListItemErrors, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findToggleButton = () => wrapper.findComponent(GlButton);
  const findCollapse = () => wrapper.findComponent(GlCollapse);
  const findErrorItems = () => wrapper.findAllByTestId('geo-list-error-item');

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders collapse component with visible false by default', () => {
      expect(findCollapse().props('visible')).toBe(false);
    });

    it('renders button with text Expand errors by default with chevron-right icon', () => {
      expect(findToggleButton().text()).toBe('Expand errors');
      expect(findToggleButton().props('icon')).toBe('chevron-right');
    });

    it('toggles collapse visibility to true when button is clicked and changes text to Collapse errors and icon to chevron-down', async () => {
      findToggleButton().vm.$emit('click');
      await nextTick();

      expect(findCollapse().props('visible')).toBe(true);
      expect(findToggleButton().text()).toBe('Collapse errors');
      expect(findToggleButton().props('icon')).toBe('chevron-down');
    });

    it('renders an error message for each item in the errorsArray', () => {
      const expectedErrors = MOCK_ERRORS.map(({ label, message }) => `${label}: ${message}`);
      expect(findErrorItems().wrappers.map((w) => w.text())).toStrictEqual(expectedErrors);
    });
  });
});
