import { GlSkeletonLoader } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import WorkflowHeader from 'ee/ai/duo_agents_platform/pages/show/components/workflow_header.vue';

describe('WorkflowHeader', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(WorkflowHeader, {
      propsData: {
        isLoading: false,
        prompt: 'Test prompt',
        ...props,
      },
    });
  };

  const findHeading = () => wrapper.find('h1');
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({ isLoading: true });
    });

    it('renders the loader', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
    });
  });

  describe('with valid prompt', () => {
    beforeEach(() => {
      createComponent({ prompt: 'This is a test prompt' });
    });

    it('renders the prompt text', () => {
      expect(findHeading().text()).toBe('This is a test prompt');
    });
  });

  describe('with empty prompt', () => {
    beforeEach(() => {
      createComponent({ prompt: '' });
    });

    it('does not render the loader', () => {
      expect(findSkeletonLoader().exists()).toBe(false);
    });

    it('renders fallback text when prompt is empty', () => {
      expect(findHeading().text()).toBe('Prompt is unavailable');
    });
  });
});
