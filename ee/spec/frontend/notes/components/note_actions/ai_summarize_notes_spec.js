import { nextTick } from 'vue';
import { GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { BV_HIDE_TOOLTIP } from '~/lib/utils/constants';
import * as aiUtils from 'ee/ai/utils';
import AiSummaryNotes from 'ee/notes/components/note_actions/ai_summarize_notes.vue';

jest.mock('ee/ai/utils');
jest.spyOn(aiUtils, 'sendDuoChatCommand');

describe('AiSummarizeNotes component', () => {
  let wrapper;
  const resourceGlobalId = 'gid://gitlab/Issue/1';

  const findButton = () => wrapper.findComponent(GlButton);

  const createWrapper = () => {
    wrapper = shallowMount(AiSummaryNotes, {
      propsData: {
        resourceGlobalId,
      },
    });
  };

  describe('on click', () => {
    it('calls sendDuoChatCommand with correct variables', async () => {
      createWrapper();

      findButton().vm.$emit('click');
      await nextTick();

      expect(aiUtils.sendDuoChatCommand).toHaveBeenCalledWith({
        question: '/summarize_comments',
        resourceId: resourceGlobalId,
      });
    });

    it('closes tooltip', async () => {
      createWrapper();

      const bsTooltipHide = jest.fn();
      wrapper.vm.$root.$on(BV_HIDE_TOOLTIP, bsTooltipHide);

      findButton().vm.$emit('click');
      await nextTick();

      expect(bsTooltipHide).toHaveBeenCalled();
    });
  });

  describe('on mouseout', () => {
    it('closes tooltip', async () => {
      createWrapper();

      const bsTooltipHide = jest.fn();
      wrapper.vm.$root.$on(BV_HIDE_TOOLTIP, bsTooltipHide);

      findButton().vm.$emit('mouseout');
      await nextTick();

      expect(bsTooltipHide).toHaveBeenCalled();
    });
  });
});
