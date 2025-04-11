import { GlPopover } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RootCauseAnalysisButton from 'ee_else_ce/ci/job_details/components/root_cause_analysis_button.vue';
import RootCauseAnalysisHotspotExperiment from 'ee_else_ce/ci/job_details/components/root_cause_analysis_hotspot_experiment.vue';
import { stubExperiments } from 'helpers/experimentation_helper';
import { sendDuoChatCommand } from 'ee/ai/utils';
import Tracking from '~/tracking';

jest.mock('ee/ai/utils', () => ({
  sendDuoChatCommand: jest.fn(),
}));

describe('RootCauseAnalysisHotspotExperiment component', () => {
  let wrapper;

  beforeEach(() => {
    jest.spyOn(Tracking, 'event');
    sendDuoChatCommand.mockClear();
    Tracking.event.mockClear();
  });

  const defaultProps = {
    jobId: 123,
    jobStatusGroup: 'failed',
    canTroubleshootJob: true,
    isBuild: true,
  };

  const findRootCauseAnalysisButton = () => wrapper.findComponent(RootCauseAnalysisButton);
  const findHotspot = () => wrapper.findByTestId('hotspot');
  const findPopover = () => wrapper.findComponent(GlPopover);

  const mountComponent = ({ props = {}, experimentVariant = 'control' } = {}) => {
    // Stub the experiment before mounting
    stubExperiments({ root_cause_analysis_hotspot: experimentVariant });

    wrapper = shallowMountExtended(RootCauseAnalysisHotspotExperiment, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GitlabExperiment: {
          template: `
            <div>
              <slot :variant="variant"></slot>
              <slot :name="variant" :variant="variant"></slot>
            </div>
          `,
          computed: {
            variant() {
              return experimentVariant;
            },
          },
        },
      },
      provide: {
        glFeatures: {
          rootCauseAnalysisHotspot: true,
        },
      },
    });

    return wrapper;
  };

  describe('control variant', () => {
    beforeEach(() => {
      mountComponent();
    });

    it('renders the RootCauseAnalysisButton', () => {
      expect(findRootCauseAnalysisButton().exists()).toBe(true);
    });

    it('passes correct props to RootCauseAnalysisButton', () => {
      expect(findRootCauseAnalysisButton().props()).toMatchObject({
        jobId: defaultProps.jobId,
        jobStatusGroup: defaultProps.jobStatusGroup,
        canTroubleshootJob: defaultProps.canTroubleshootJob,
      });
    });

    it('does not render hotspot', () => {
      expect(findHotspot().exists()).toBe(false);
    });

    it('tracks click_troubleshoot when button is clicked', async () => {
      Tracking.event.mockClear();

      findRootCauseAnalysisButton().vm.$emit('duo-called');
      await nextTick();

      expect(Tracking.event).toHaveBeenCalledWith(
        undefined,
        'click_troubleshoot',
        expect.objectContaining({
          context: expect.objectContaining({
            data: { experiment: 'root_cause_analysis_hotspot', variant: 'control' },
          }),
        }),
      );
    });
  });

  describe('candidate variant', () => {
    beforeEach(() => {
      mountComponent({ experimentVariant: 'candidate' });
    });

    it('renders the RootCauseAnalysisButton', () => {
      expect(findRootCauseAnalysisButton().exists()).toBe(true);
    });

    it('renders the hotspot', () => {
      expect(findHotspot().exists()).toBe(true);
    });

    describe('user interactions', () => {
      it('shows popover when hotspot is clicked', async () => {
        expect(findPopover().props('show')).toBe(false);

        findHotspot().trigger('click.stop');
        await nextTick();

        expect(findPopover().props('show')).toBe(true);
      });

      it('hides popover when hotspot is clicked again', async () => {
        findHotspot().trigger('click.stop');
        await nextTick();

        expect(findPopover().props('show')).toBe(true);

        findHotspot().trigger('click.stop');
        await nextTick();

        expect(findPopover().props('show')).toBe(false);
      });

      it('dismisses popover when close button is clicked', async () => {
        findHotspot().trigger('click.stop');
        await nextTick();

        findPopover().vm.$emit('close-button-clicked');
        await nextTick();

        findPopover().vm.$emit('hidden');
        await nextTick();

        expect(findPopover().props('show')).toBe(false);
      });

      it('tracks click_troubleshoot and hides popover when troubleshoot button is clicked with open popover', async () => {
        findHotspot().trigger('click.stop');
        await nextTick();

        Tracking.event.mockClear();
        findRootCauseAnalysisButton().vm.$emit('duo-called');
        await nextTick();

        expect(Tracking.event).toHaveBeenCalledWith(
          undefined,
          'click_troubleshoot',
          expect.any(Object),
        );
        expect(findPopover().props('show')).toBe(false);
      });
    });

    describe('tracking', () => {
      it('tracks click_troubleshoot when button is clicked', async () => {
        Tracking.event.mockClear();

        findRootCauseAnalysisButton().vm.$emit('duo-called');
        await nextTick();

        expect(Tracking.event).toHaveBeenCalledWith(
          undefined,
          'click_troubleshoot',
          expect.any(Object),
        );
      });

      it('tracks click_hotspot when hotspot is clicked', async () => {
        Tracking.event.mockClear();

        findHotspot().trigger('click.stop');
        await nextTick();

        expect(Tracking.event).toHaveBeenCalledWith(undefined, 'click_hotspot', expect.any(Object));
      });

      it('does not track render_hotspot when popover is closed', async () => {
        findHotspot().trigger('click.stop');
        await nextTick();

        Tracking.event.mockClear();
        findHotspot().trigger('click.stop');
        await nextTick();

        // Check that render_hotspot was not called
        const calls = Tracking.event.mock.calls.map((call) => call[1]);
        expect(calls).not.toContain('render_hotspot');
      });

      it('tracks dismiss_popover when popover is closed via X button', async () => {
        findHotspot().trigger('click.stop');
        await nextTick();

        Tracking.event.mockClear();
        findPopover().vm.$emit('close-button-clicked');
        await nextTick();

        expect(Tracking.event).toHaveBeenCalledWith(
          undefined,
          'dismiss_popover',
          expect.any(Object),
        );
      });
    });
  });
});
