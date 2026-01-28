import { shallowMount } from '@vue/test-utils';
import NotesActivityHeader from '~/notes/components/notes_activity_header.vue';
import { notesFilters } from 'jest/notes/mock_data';

import AiSummarizeNotes from 'ee_component/notes/components/note_actions/ai_summarize_notes.vue';

describe('EE ~/notes/components/notes_activity_header.vue', () => {
  let wrapper;

  const findAiSummarizeNotes = () => wrapper.findComponent(AiSummarizeNotes);

  const createComponent = ({ provide } = {}) => {
    wrapper = shallowMount(NotesActivityHeader, {
      propsData: {
        notesFilters,
      },
      provide: {
        resourceGlobalId: 'resourceGlobalId',
        glAbilities: { summarizeComments: true },
        glLicensedFeatures: { summarizeComments: true },
        ...provide,
      },
      stubs: {
        AiSummarizeNotes,
      },
    });
  };

  describe('when summarizeComments is enabled', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders AI summarize notes component', () => {
      expect(findAiSummarizeNotes().props()).toEqual({
        loading: false,
        resourceGlobalId: 'resourceGlobalId',
        size: 'medium',
        workItemType: '',
      });
    });
  });

  describe('when summarize comments is disabled', () => {
    it('does not renders AI summarize when there is no ability', () => {
      createComponent({
        provide: { glAbilities: { summarizeComments: false } },
      });

      expect(findAiSummarizeNotes().exists()).toBe(false);
    });

    it('does not renders AI summarize when feature is not enabled', () => {
      createComponent({
        provide: { glLicensedFeatures: { summarizeComments: false } },
      });

      expect(findAiSummarizeNotes().exists()).toBe(false);
    });
  });
});
