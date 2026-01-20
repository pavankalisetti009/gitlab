import { GlBreakpointInstance } from '@gitlab/ui/src/utils';
import { GlIcon, GlSprintf } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiPanelEmptyState from 'ee/ai/components/ai_panel_empty_state.vue';
import Cookies from '~/lib/utils/cookies';

const newTrialPathMock = '/-/trials/new';
const trialDurationMock = '20';

const triggerResize = () => {
  window.dispatchEvent(new Event('resize'));
};

describe('AiPanelEmptyState', () => {
  let wrapper;

  const findPanelContent = () => wrapper.findByTestId('panel-content');
  const findTogglePanelContentButton = () => wrapper.findByTestId('toggle-panel-content-button');
  const findEmptyStateText = () => wrapper.findByTestId('empty-state-text');
  const findStartTrialLink = () => wrapper.findByTestId('start-trial-link');
  const findLearnMoreLink = () => wrapper.findByTestId('learn-more-link');
  const findWorkflowExamples = () => wrapper.findAllByTestId('workflow-example');

  const createComponent = () => {
    wrapper = shallowMountExtended(AiPanelEmptyState, {
      provide: {
        newTrialPath: newTrialPathMock,
        trialDuration: trialDurationMock,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  beforeEach(() => {
    Cookies.remove('ai_panel_empty_state');
  });

  it('renders the correct content', () => {
    createComponent();
    const text = findEmptyStateText();
    const workflowExamples = findWorkflowExamples();

    expect(text.text()).toMatchInterpolatedText(
      'Start your free 20-day trial to collaborate with agents and automate workflows across your development process.',
    );

    expect(findStartTrialLink().props('href')).toBe(newTrialPathMock);
    expect(findLearnMoreLink().props('href')).toBe('/help/user/permissions.md');

    expect(workflowExamples.at(0).findComponent(GlIcon).props('name')).toBe('merge-request');
    expect(workflowExamples.at(0).text()).toContain('Review a merge request');
    expect(workflowExamples.at(0).text()).toContain('Identify code improvements');

    expect(workflowExamples.at(1).findComponent(GlIcon).props('name')).toBe('pipeline');
    expect(workflowExamples.at(1).text()).toContain('Fix a failing pipeline');
    expect(workflowExamples.at(1).text()).toContain(
      'Analyze pipeline failures and get fix suggestions',
    );
  });

  it('does not set the cookie initially', async () => {
    createComponent();
    await nextTick();

    expect(Cookies.get('ai_panel_empty_state')).toBeUndefined();
  });

  describe('on desktop', () => {
    beforeEach(() => {
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(true);
      createComponent();
    });

    it('starts with content expanded', () => {
      expect(findPanelContent().exists()).toBe(true);
    });

    it('collapses the content if the window gets narrower', async () => {
      GlBreakpointInstance.isDesktop.mockReturnValue(false);
      triggerResize();
      await nextTick();

      expect(findPanelContent().exists()).toBe(false);
      expect(Cookies.get('ai_panel_empty_state')).toBe('AI_PANEL_EMPTY_STATE_CLOSED');
    });

    it('sets the cookie value when clicking on the toggle button', async () => {
      findTogglePanelContentButton().vm.$emit('click');
      await nextTick();

      expect(Cookies.get('ai_panel_empty_state')).toBe('AI_PANEL_EMPTY_STATE_CLOSED');
    });
  });

  describe('when the panel content was previously collapsed manually', () => {
    beforeEach(() => {
      Cookies.set('ai_panel_empty_state', 'AI_PANEL_EMPTY_STATE_CLOSED');
      createComponent();
    });

    it('starts with content collapsed', () => {
      expect(findPanelContent().exists()).toBe(false);
    });
  });

  describe('on mobile', () => {
    beforeEach(() => {
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(false);
    });

    describe('when the panel was not toggled manually yet', () => {
      beforeEach(() => {
        createComponent();
      });

      it('starts with content collapsed', () => {
        expect(findPanelContent().exists()).toBe(false);
      });

      it('sets the cookie value when clicking on the toggle button', async () => {
        findTogglePanelContentButton().vm.$emit('click');
        await nextTick();

        expect(Cookies.get('ai_panel_empty_state')).toBe('AI_PANEL_EMPTY_STATE_OPEN');
      });
    });

    describe('when the panel content was previously expanded manually', () => {
      beforeEach(() => {
        Cookies.set('ai_panel_empty_state', 'AI_PANEL_EMPTY_STATE_OPEN');
        createComponent();
      });

      it('starts with content expanded', () => {
        expect(findPanelContent().exists()).toBe(true);
      });
    });
  });
});
