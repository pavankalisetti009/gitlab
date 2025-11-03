import { shallowMount } from '@vue/test-utils';
import {
  GlFormTextarea,
  GlLink,
  GlButton,
  GlEmptyState,
  GlDashboardPanel,
  GlAlert,
} from '@gitlab/ui';
import DataExplorer from 'ee/vue_shared/components/data_explorer/data_explorer.vue';
import ModalCopyButton from '~/vue_shared/components/modal_copy_button.vue';
import GlqlResolver from '~/glql/components/common/resolver.vue';

describe('Data Explorer', () => {
  let wrapper;

  const createWrapper = () => {
    wrapper = shallowMount(DataExplorer);
  };

  const getTextArea = () => wrapper.findComponent(GlFormTextarea);
  const getSubmitBtn = () => wrapper.findComponent(GlButton);
  const getResolver = () => wrapper.findComponent(GlqlResolver);
  const getErrorAlert = () => wrapper.findComponent(GlAlert);
  const getPanel = () => wrapper.findComponent(GlDashboardPanel);

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
      expect(getSubmitBtn().text()).toBe('Run query');
      expect(getSubmitBtn().attributes('disabled')).toBeDefined();
    });

    it('renders a dashboard panel with no title', () => {
      expect(getPanel().props('title')).toBe('');
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

      it('does not render the GLQL resolver', () => {
        expect(getResolver().exists()).toBe(false);
      });

      describe('when query is submitted', () => {
        beforeEach(() => {
          return getSubmitBtn().vm.$emit('click');
        });

        it('submits the inputted query to the resolver', () => {
          expect(getResolver().props('glqlQuery')).toBe(query);
        });

        describe('when resolver returns a title', () => {
          const title = 'MATHEMATICAL!!!';
          beforeEach(() => {
            getResolver().vm.$emit('change', { config: { title } });
          });

          it('uses the title for the dashboard panel', () => {
            expect(getPanel().props('title')).toBe(title);
          });
        });

        describe('when resolver throws an error', () => {
          const message = 'oh glob';

          beforeEach(() => {
            getResolver().vm.$emit('change', { error: new Error(message) });
          });

          it('does not render the GLQL resolver', () => {
            expect(getResolver().exists()).toBe(false);
          });

          it('shows an alert with the error message', () => {
            expect(getErrorAlert().text()).toEqual(message);
          });

          describe('when running the failed query again', () => {
            beforeEach(() => {
              return getSubmitBtn().vm.$emit('click');
            });

            it('hides the error message', () => {
              expect(getErrorAlert().exists()).toBe(false);
            });
          });
        });
      });
    });
  });
});
