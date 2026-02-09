import { GlBreakpointInstance } from '@gitlab/ui/src/utils';
import { GlIcon, GlSprintf } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import AiPanelEmptyState from 'ee/ai/components/ai_panel_empty_state.vue';
import Cookies from '~/lib/utils/cookies';

const newTrialPathMock = '/-/trials/new';
const trialDurationMock = '20';

const triggerResize = () => {
  window.dispatchEvent(new Event('resize'));
};
const { bindInternalEventDocument } = useMockInternalEventsTracking();

describe('AiPanelEmptyState', () => {
  let wrapper;

  const findPanelContent = () => wrapper.findByTestId('panel-content');
  const findTogglePanelContentButton = () => wrapper.findByTestId('toggle-panel-content-button');
  const findClosePanelContentButton = () =>
    wrapper.findByTestId('content-container-collapse-button');
  const findEmptyStateText = () => wrapper.findByTestId('empty-state-text');
  const findStartTrialLink = () => wrapper.findByTestId('start-trial-link');
  const findLearnMoreLink = () => wrapper.findByTestId('learn-more-link');
  const findWorkflowExamples = () => wrapper.findAllByTestId('workflow-example');

  const createComponent = (provide = {}) => {
    wrapper = shallowMountExtended(AiPanelEmptyState, {
      provide: {
        canStartTrial: true,
        newTrialPath: newTrialPathMock,
        trialDuration: trialDurationMock,
        ...provide,
      },
      stubs: {
        GlSprintf,
      },
    });

    return {
      andExpandPanel: () => findTogglePanelContentButton().vm.$emit('click'),
    };
  };

  beforeEach(() => {
    Cookies.remove('ai_panel_empty_state');
  });

  it('starts with content collapsed', () => {
    createComponent();

    expect(findPanelContent().exists()).toBe(false);
  });

  it('renders the correct content', async () => {
    await createComponent().andExpandPanel();
    const text = findEmptyStateText();
    const workflowExamples = findWorkflowExamples();

    expect(text.text()).toMatchInterpolatedText(
      'Start your free 20-day trial now to accelerate your software delivery. Automate tasks with AI agents, from searching projects to creating commits.',
    );

    expect(findStartTrialLink().props('href')).toBe(newTrialPathMock);
    expect(findLearnMoreLink().props('href')).toBe('/help/user/duo_agent_platform/_index.md');

    expect(workflowExamples.at(0).findComponent(GlIcon).props('name')).toBe('merge-request');
    expect(workflowExamples.at(0).text()).toContain('Review a merge request');
    expect(workflowExamples.at(0).text()).toContain('Identify code improvements');

    expect(workflowExamples.at(1).findComponent(GlIcon).props('name')).toBe('pipeline');
    expect(workflowExamples.at(1).text()).toContain('Fix a failing pipeline');
    expect(workflowExamples.at(1).text()).toContain(
      'Analyze pipeline failures and get fix suggestions',
    );
  });

  it('tracks the `view_duo_agentic_not_available_empty_state` on mount', () => {
    createComponent();
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    expect(trackEventSpy).toHaveBeenCalledWith(
      'view_duo_agentic_not_available_empty_state',
      {},
      undefined,
    );
  });

  it('adds the correct tracking properties to the "Start a Free Trial" link', async () => {
    await createComponent().andExpandPanel();

    expect(findStartTrialLink().attributes()).toMatchObject({
      'data-event-tracking': 'click_link',
      'data-event-label': 'click_duo_agentic_not_available_empty_state_start_trial',
    });
  });

  it('adds the correct tracking properties to the "Learn more" link', async () => {
    await createComponent().andExpandPanel();

    expect(findLearnMoreLink().attributes()).toMatchObject({
      'data-event-tracking': 'click_link',
      'data-event-label': 'click_duo_agentic_not_available_empty_state_learn_more',
    });
  });

  it('does not set the cookie initially', async () => {
    createComponent();
    await nextTick();

    expect(Cookies.get('ai_panel_empty_state')).toBeUndefined();
  });

  it('collapses the panel upon clicking the close button', async () => {
    await createComponent().andExpandPanel();

    expect(findPanelContent().exists()).toBe(true);
    expect(Cookies.get('ai_panel_empty_state')).toBe('AI_PANEL_EMPTY_STATE_OPEN');

    findClosePanelContentButton().vm.$emit('click');
    await nextTick();

    expect(findPanelContent().exists()).toBe(false);
    expect(Cookies.get('ai_panel_empty_state')).toBe('AI_PANEL_EMPTY_STATE_CLOSED');
  });

  describe('on desktop', () => {
    beforeEach(() => {
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(true);
      return createComponent().andExpandPanel();
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
      return createComponent();
    });

    it('starts with content collapsed', () => {
      expect(findPanelContent().exists()).toBe(false);
    });
  });

  describe('when the panel content was previously expanded manually', () => {
    beforeEach(() => {
      Cookies.set('ai_panel_empty_state', 'AI_PANEL_EMPTY_STATE_OPEN');
      return createComponent();
    });

    it('starts with content expanded', () => {
      expect(findPanelContent().exists()).toBe(true);
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

  describe('when the user cannot start a trial', () => {
    it('renders the correct content', async () => {
      await createComponent({
        canStartTrial: false,
      }).andExpandPanel();

      expect(findEmptyStateText().text()).toMatchInterpolatedText(
        "You don't have permission to use GitLab Duo Agent Platform in this project. Learn more.",
      );
      expect(findLearnMoreLink().props('href')).toBe('/help/user/duo_agent_platform/_index.md');
    });

    it('shows the correct text when the namespace is a group', async () => {
      await createComponent({
        canStartTrial: false,
        namespaceType: 'Group',
      }).andExpandPanel();

      expect(findEmptyStateText().text()).toMatchInterpolatedText(
        "You don't have permission to use GitLab Duo Agent Platform in this group. Learn more.",
      );
    });

    it('adds the correct tracking properties to the "Learn more" link', async () => {
      await createComponent({
        canStartTrial: false,
      }).andExpandPanel();

      expect(findLearnMoreLink().attributes()).toMatchObject({
        'data-event-tracking': 'click_link',
        'data-event-label': 'click_duo_agentic_not_available_empty_state_learn_more',
      });
    });
  });
});
