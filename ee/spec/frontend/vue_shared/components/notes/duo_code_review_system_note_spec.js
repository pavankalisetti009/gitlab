import { mount } from '@vue/test-utils';
import createStore from '~/notes/stores';
import DuoCodeReviewSystemNote from 'ee/vue_shared/components/notes/duo_code_review_system_note.vue';

describe('Duo code review system note component', () => {
  let vm;

  function createComponent(propsData = {}) {
    const store = createStore();
    store.dispatch('setTargetNoteHash', `note_${propsData.note.id}`);

    vm = mount(DuoCodeReviewSystemNote, {
      store,
      propsData,
    });
  }

  beforeEach(() => {
    createComponent({
      note: {
        id: '1424',
        author: {
          id: 1,
          name: 'Root',
          username: 'root',
          state: 'active',
          avatar_url: 'path',
          path: '/root',
          user_type: 'duo_code_review_bot',
        },
        note_html: '<p dir="auto">closed</p>',
        created_at: '2017-08-02T10:51:58.559Z',
      },
    });
  });

  it('renders loading icon', () => {
    expect(vm.find('[data-testid="duo-loading-icon"]').exists()).toBe(true);
  });

  it('renders avatar', () => {
    expect(vm.find('[data-testid="system-note-avatar"]').exists()).toBe(true);
  });
});
