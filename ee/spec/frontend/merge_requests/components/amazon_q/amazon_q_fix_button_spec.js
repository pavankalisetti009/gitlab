import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlAlert, GlButton } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import waitForPromises from 'helpers/wait_for_promises';
import AmazonQFixButton from 'ee_component/merge_requests/components/amazon_q/amazon_q_fix_button.vue';
import axios from '~/lib/utils/axios_utils';

const REVIEW_FINDING_KEYWORDS = ['We detected', 'We recommend', 'Severity:'];

const mockNote = {
  id: 1,
  amazon_q_quick_actions_path: '/amazon_q_quick_actions',
};

describe('AmazonQFixButton', () => {
  let wrapper;
  let mockAxios;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(AmazonQFixButton, {
      propsData: {
        note: { ...mockNote, ...props },
      },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);
  const findAlert = () => wrapper.findComponent(GlAlert);

  beforeEach(() => {
    mockAxios = new MockAdapter(axios);
  });

  afterEach(() => {
    mockAxios.restore();
  });

  describe('component rendering', () => {
    it.each(REVIEW_FINDING_KEYWORDS)(
      'renders the button when note contains the keyword: %s',
      (keyword) => {
        createComponent({ note: `This is a note with ${keyword} in it.` });
        expect(findButton().exists()).toBe(true);
      },
    );

    it('does not render the button when amazonQQuickActionsPath is not present', () => {
      createComponent({ amazon_q_quick_actions_path: null, note: 'We detected an issue.' });
      expect(findButton().exists()).toBe(false);
    });

    it('does not render the button when note does not contain any of the keywords', () => {
      createComponent({ note: 'This is a regular comment.' });
      expect(findButton().exists()).toBe(false);
    });
  });

  describe('button interactions', () => {
    beforeEach(() => {
      createComponent({ note: 'We detected an issue.' });
    });

    describe('when clicked', () => {
      beforeEach(async () => {
        mockAxios.onPost(mockNote.amazon_q_quick_actions_path).reply(200);
        findButton().vm.$emit('click');
        await nextTick();
      });

      it('shows loading state', () => {
        expect(findButton().props('loading')).toBe(true);
      });

      it('makes API call', async () => {
        await waitForPromises();

        expect(mockAxios.history.post.length).toBe(1);
        expect(mockAxios.history.post[0].url).toBe(mockNote.amazon_q_quick_actions_path);
        expect(JSON.parse(mockAxios.history.post[0].data)).toEqual({
          note_id: mockNote.id,
          command: 'fix',
        });
      });
    });

    describe('error handling and alert interactions', () => {
      beforeEach(async () => {
        mockAxios.onPost(mockNote.amazon_q_quick_actions_path).reply(500);
        findButton().vm.$emit('click');
        await waitForPromises();
      });

      it('shows error alert when API call fails', () => {
        expect(findAlert().exists()).toBe(true);
        expect(findAlert().props('variant')).toBe('danger');
      });

      it('dismisses the alert when dismiss is clicked', async () => {
        findAlert().vm.$emit('dismiss');
        await nextTick();

        expect(findAlert().exists()).toBe(false);
      });
    });
  });
});
