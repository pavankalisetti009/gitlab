import { shallowMount } from '@vue/test-utils';
import { GlFormTextarea, GlLink, GlButton, GlEmptyState } from '@gitlab/ui';
import DataExplorer from 'ee/vue_shared/components/data_explorer/data_explorer.vue';
import ModalCopyButton from '~/vue_shared/components/modal_copy_button.vue';

describe('Data Explorer', () => {
  let wrapper;

  const createWrapper = () => {
    wrapper = shallowMount(DataExplorer);
  };

  const getTextArea = () => wrapper.findComponent(GlFormTextarea);

  describe('when rendered', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the text area', () => {
      expect(getTextArea().exists()).toBe(true);
    });

    it('does not render the copy query button', () => {
      expect(wrapper.findComponent(ModalCopyButton).exists()).toBe(false);
    });

    it('renders the GLQL docs link', () => {
      const link = wrapper.findComponent(GlLink);
      expect(link.text()).toBe('What is GLQL?');
      expect(link.attributes('href')).toBe('/help/user/glql/_index');
    });

    it('renders a disabled `Run query` button', () => {
      const button = wrapper.findComponent(GlButton);
      expect(button.text()).toBe('Run query');
      expect(button.attributes('disabled')).toBeDefined();
    });

    it('renders an empty state for the query preview', () => {
      const emptyState = wrapper.findComponent(GlEmptyState);
      expect(emptyState.props()).toMatchObject({
        title: 'Preview not available',
        description: 'Start by typing a GLQL query.',
        svgPath: expect.any(String),
      });
    });

    describe('with query input', () => {
      const query = 'zzzzz';

      beforeEach(() => {
        return getTextArea().vm.$emit('input', query);
      });

      it('renders the copy query button', () => {
        expect(wrapper.findComponent(ModalCopyButton).props()).toMatchObject({
          title: 'Copy query',
          text: query,
        });
      });

      it('renders a clickable `Run query` button', () => {
        const button = wrapper.findComponent(GlButton);
        expect(button.text()).toBe('Run query');
        expect(button.attributes('disabled')).toBeUndefined();
      });
    });
  });
});
