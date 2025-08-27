import { GlAlert, GlFormRadioGroup } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { VISIBILITY_LEVEL_PRIVATE, VISIBILITY_LEVEL_PUBLIC } from 'ee/ai/catalog/constants';
import VisibilityLevelRadioGroup from 'ee/ai/catalog/components/visibility_level_radio_group.vue';

describe('VisibilityLevelRadioGroup', () => {
  let wrapper;

  const findFormRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findVisibilityLevelAlert = () => wrapper.findComponent(GlAlert);

  const defaultProps = {
    id: '1',
    initialValue: false,
    texts: {
      textPrivate: 'Private text',
      textPublic: 'Public text',
      alertTextPrivate: 'A public item can be made private only if it is not used.',
      alertTextPublic: 'This item can be made private if it is not used.',
    },
    isEditMode: false,
    value: VISIBILITY_LEVEL_PUBLIC,
  };

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(VisibilityLevelRadioGroup, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  describe('Visibility Level Radio Group', () => {
    it('emits the input event', () => {
      createWrapper();

      findFormRadioGroup().vm.$emit('input', VISIBILITY_LEVEL_PUBLIC);

      expect(wrapper.emitted('input')).toHaveLength(1);
      expect(wrapper.emitted('input')[0][0]).toBe(VISIBILITY_LEVEL_PUBLIC);

      findFormRadioGroup().vm.$emit('input', VISIBILITY_LEVEL_PRIVATE);

      expect(wrapper.emitted('input')).toHaveLength(2);
      expect(wrapper.emitted('input')[1][0]).toBe(VISIBILITY_LEVEL_PRIVATE);
    });

    describe.each`
      selectedVisibility | value                       | expectedAlertText
      ${'private'}       | ${VISIBILITY_LEVEL_PRIVATE} | ${false}
      ${'public'}        | ${VISIBILITY_LEVEL_PUBLIC}  | ${defaultProps.texts.alertTextPrivate}
    `(
      'when creating an item and "$selectedVisibility" visibility is selected',
      ({ value, expectedAlertText }) => {
        beforeEach(() => {
          createWrapper({
            value,
          });
        });

        it(`${expectedAlertText ? 'renders' : 'does not render'} visibility alert`, () => {
          expect(findVisibilityLevelAlert().exists()).toBe(Boolean(expectedAlertText));
          if (expectedAlertText) {
            expect(findVisibilityLevelAlert().text()).toBe(expectedAlertText);
          }
        });
      },
    );

    describe.each`
      initialVisibility | initialValue | selectedVisibility | value                       | expectedAlertText
      ${'private'}      | ${false}     | ${'private'}       | ${VISIBILITY_LEVEL_PRIVATE} | ${false}
      ${'private'}      | ${false}     | ${'public'}        | ${VISIBILITY_LEVEL_PUBLIC}  | ${defaultProps.texts.alertTextPrivate}
      ${'public'}       | ${true}      | ${'private'}       | ${VISIBILITY_LEVEL_PRIVATE} | ${defaultProps.texts.alertTextPublic}
      ${'public'}       | ${true}      | ${'public'}        | ${VISIBILITY_LEVEL_PUBLIC}  | ${false}
    `(
      'when editing a $initialVisibility item and "$selectedVisibility" visibility is selected',
      ({ initialValue, value, expectedAlertText }) => {
        beforeEach(() => {
          createWrapper({
            isEditMode: true,
            initialValue,
            value,
          });
        });

        it(`${expectedAlertText ? 'renders' : 'does not render'} visibility alert`, () => {
          expect(findVisibilityLevelAlert().exists()).toBe(Boolean(expectedAlertText));
          if (expectedAlertText) {
            expect(findVisibilityLevelAlert().text()).toBe(expectedAlertText);
          }
        });
      },
    );
  });
});
