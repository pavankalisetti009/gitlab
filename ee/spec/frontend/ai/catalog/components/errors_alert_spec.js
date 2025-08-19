import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlAlert } from '@gitlab/ui';
import ErrorsAlert from 'ee/ai/catalog/components/errors_alert.vue';

describe('ErrorsAlert', () => {
  let wrapper;
  const mockErrorMessage1 = 'The agent could not be created';
  const mockErrorMessage2 = 'The flow could not be created';

  const findErrorAlert = () => wrapper.findComponent(GlAlert);

  const createWrapper = (props = { errorMessages: [] }) => {
    wrapper = shallowMount(ErrorsAlert, {
      propsData: {
        ...props,
      },
    });
  };

  describe('Initial Rendering', () => {
    it('does not render error alert', () => {
      createWrapper();

      expect(findErrorAlert().exists()).toBe(false);
    });

    it('renders error alert when there is one error', () => {
      createWrapper({ errorMessages: [mockErrorMessage1] });

      expect(findErrorAlert().text()).toBe(mockErrorMessage1);
    });

    it('renders error alert with list for multiple errors', () => {
      createWrapper({ errorMessages: [mockErrorMessage1, mockErrorMessage2] });

      expect(findErrorAlert().findAll('li')).toHaveLength(2);
    });
  });

  describe('when the component receives an error after initial rendering', () => {
    const originalScrollIntoView = HTMLElement.prototype.scrollIntoView;
    const scrollIntoViewMock = jest.fn();

    beforeEach(() => {
      HTMLElement.prototype.scrollIntoView = scrollIntoViewMock;
      createWrapper();
    });

    afterEach(() => {
      HTMLElement.prototype.scrollIntoView = originalScrollIntoView;
    });

    it('scrolls to error alert when errorMessages are set', async () => {
      await wrapper.setProps({ errorMessages: ['Error occurred'] });
      await nextTick();

      expect(scrollIntoViewMock).toHaveBeenCalledWith({
        behavior: 'smooth',
        block: 'center',
      });
    });
  });

  describe('Interactions', () => {
    describe('when dismissing the alert', () => {
      beforeEach(() => {
        createWrapper({ errorMessages: [mockErrorMessage1] });
      });

      it('emits dismiss event when clicked on dismiss icon', () => {
        findErrorAlert().vm.$emit('dismiss');

        expect(wrapper.emitted('dismiss')).toHaveLength(1);
      });
    });
  });
});
