import ValueStreamFormContentActions from 'ee/analytics/cycle_analytics/vsa_settings/components/value_stream_form_content_actions.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('ValueStreamFormContentActions', () => {
  const vsaPath = '/mockVsaPath/test';

  let wrapper;

  const findPrimaryBtn = () => wrapper.findByTestId('primary-button');
  const findCancelBtn = () => wrapper.findByTestId('cancel-button');

  const createComponent = ({ props = {}, valueStreamId = -1 } = {}) => {
    wrapper = shallowMountExtended(ValueStreamFormContentActions, {
      provide: { vsaPath, valueStream: { id: valueStreamId } },
      propsData: {
        ...props,
      },
    });
  };

  describe.each`
    isEditing | valueStreamId | text                   | cancelHref
    ${false}  | ${-1}         | ${'New value stream'}  | ${vsaPath}
    ${true}   | ${-1}         | ${'Save value stream'} | ${vsaPath}
    ${true}   | ${13}         | ${'Save value stream'} | ${`/mockVsaPath/test?value_stream_id=13`}
  `(
    'when `valueStreamId` is `$valueStreamId`',
    ({ isEditing, valueStreamId, text, cancelHref }) => {
      beforeEach(() => {
        createComponent({ valueStreamId, props: { isEditing } });
      });

      it('renders primary action correctly', () => {
        expect(findPrimaryBtn().text()).toBe(text);
        expect(findPrimaryBtn().props()).toMatchObject({
          variant: 'confirm',
          loading: false,
          disabled: false,
        });
      });

      it('emits `clickPrimaryAction` event when primary action is selected', () => {
        findPrimaryBtn().vm.$emit('click');

        expect(wrapper.emitted('clickPrimaryAction')).toHaveLength(1);
      });

      it('renders cancel button link correctly', () => {
        expect(findCancelBtn().props('disabled')).toBe(false);
        expect(findCancelBtn().attributes('href')).toBe(cancelHref);
      });

      describe('isLoading=true', () => {
        beforeEach(() => {
          createComponent({ valueStreamId, props: { isEditing, isLoading: true } });
        });

        it('sets primary action to a loading state', () => {
          expect(findPrimaryBtn().props('loading')).toBe(true);
        });

        it('disables all other actions', () => {
          expect(findCancelBtn().props('disabled')).toBe(true);
        });
      });
    },
  );
});
