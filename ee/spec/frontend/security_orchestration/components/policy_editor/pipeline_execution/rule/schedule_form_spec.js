import { GlCollapsibleListbox, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ScheduleForm from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/schedule_form.vue';
import BranchSelection from 'ee/security_orchestration/components/policy_editor/scan_result/rule/branch_selection.vue';
import TimezoneDropdown from '~/vue_shared/components/timezone_dropdown/timezone_dropdown.vue';

jest.mock('ee/security_orchestration/components/policy_editor/utils', () => ({
  ...jest.requireActual('ee/security_orchestration/components/policy_editor/utils'),
  getHostname: jest.fn().mockReturnValue('gitlab.example.com'),
}));

describe('ScheduleForm', () => {
  let wrapper;
  const defaultSchedule = {
    type: 'daily',
    time_window: { value: 3600 },
    branch_type: 'protected',
    timezone: 'America/New_York',
  };
  const mockTimezones = [
    { identifier: 'America/New_York', name: 'Eastern Time' },
    { identifier: 'America/Los_Angeles', name: 'Pacific Time' },
  ];

  const createComponent = (props = {}, provide = {}) => {
    wrapper = shallowMountExtended(ScheduleForm, {
      propsData: { schedule: defaultSchedule, ...props },
      stubs: { GlSprintf },
      provide: { timezones: mockTimezones, ...provide },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findBranchSelection = () => wrapper.findComponent(BranchSelection);
  const findTimezoneDropdown = () => wrapper.findComponent(TimezoneDropdown);
  const findTimeDropdown = () => wrapper.findByTestId('time-dropdown');
  const findWeekdayDropdown = () => wrapper.findByTestId('weekday-dropdown');
  const findMonthlyDaysDropdown = () => wrapper.findByTestId('monthly-days-dropdown');

  describe('rendering', () => {
    it('displays the message', () => {
      createComponent();
      expect(wrapper.text()).toContain('Schedule to run for');
    });

    it('displays the details', () => {
      createComponent();
      expect(wrapper.text()).toContain('at the following times:');
    });

    it('renders the cadence selector with correct options', () => {
      createComponent();
      const listbox = findListbox();
      expect(listbox.exists()).toBe(true);
      expect(listbox.props('items')).toEqual([
        { value: 'daily', text: 'Daily' },
        { value: 'weekly', text: 'Weekly' },
        { value: 'monthly', text: 'Monthly' },
      ]);
    });

    it('sets the selected value based on schedule prop', () => {
      createComponent({ schedule: { type: 'weekly' } });
      expect(findListbox().props('selected')).toBe('weekly');
    });

    it('renders the branch selection component', () => {
      createComponent();
      expect(findBranchSelection().exists()).toBe(true);
      expect(findBranchSelection().props('initRule')).toEqual({
        branch_type: 'protected',
        type: 'daily',
      });
    });

    describe('timezone dropdown', () => {
      it('renders the timezone dropdown', () => {
        createComponent();
        const timezoneDropdown = findTimezoneDropdown();
        expect(timezoneDropdown.exists()).toBe(true);
        expect(timezoneDropdown.props()).toMatchObject({
          timezoneData: mockTimezones,
          value: 'America/New_York',
          headerText: 'Select timezone',
        });
        expect(timezoneDropdown.attributes('title')).toBe('on gitlab.example.com');
      });
    });

    it('renders time dropdown', () => {
      createComponent({ schedule: { type: 'daily', start_time: '09:00' } });
      const timeDropdown = findTimeDropdown();
      expect(timeDropdown.exists()).toBe(true);
      expect(timeDropdown.props('selected')).toBe('09:00');
    });

    describe('weekday dropdown', () => {
      it('renders weekday dropdown for weekly schedule', () => {
        createComponent({ schedule: { type: 'weekly', days: ['monday'] } });
        const weekdayDropdown = findWeekdayDropdown();
        expect(weekdayDropdown.exists()).toBe(true);
        expect(weekdayDropdown.props('selected')).toEqual(['monday']);
        expect(weekdayDropdown.props('multiple')).toBe(true);
      });

      describe('weekdayToggleText', () => {
        it('returns placeholder when the days property is not available', () => {
          createComponent({ schedule: { type: 'weekly' } });
          expect(findWeekdayDropdown().props('toggleText')).toBe('Select a day');
        });

        it('returns placeholder when no days are selected', () => {
          createComponent({ schedule: { type: 'weekly', days: [] } });
          expect(findWeekdayDropdown().props('toggleText')).toBe('Select a day');
        });

        it('returns single day when one day is selected', () => {
          createComponent({ schedule: { type: 'weekly', days: ['monday'] } });
          expect(findWeekdayDropdown().props('toggleText')).toBe('Monday');
        });

        it('returns two days when two days are selected', () => {
          createComponent({ schedule: { type: 'weekly', days: ['monday', 'friday'] } });
          expect(findWeekdayDropdown().props('toggleText')).toBe('Monday, Friday');
        });

        it('returns truncated text when more than two days are selected', () => {
          createComponent({
            schedule: { type: 'weekly', days: ['monday', 'wednesday', 'friday'] },
          });
          expect(findWeekdayDropdown().props('toggleText')).toBe('Monday, Wednesday +1 more');
        });
      });
    });

    describe('monthly dropdown', () => {
      it('renders monthly days when schedule type is monthly', () => {
        createComponent({ schedule: { type: 'monthly', days_of_month: [1, 15] } });
        const monthlyDropdown = findMonthlyDaysDropdown();
        expect(monthlyDropdown.exists()).toBe(true);
        expect(monthlyDropdown.props('selected')).toEqual([1, 15]);
        expect(monthlyDropdown.props('multiple')).toBe(true);
      });
    });
  });

  describe('event handling', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('branch selection', () => {
      it('handles branch type selection changes', async () => {
        const branchTypeData = { branch_type: 'all' };
        await findBranchSelection().vm.$emit('set-branch-type', branchTypeData);
        expect(wrapper.emitted('changed')).toMatchObject([[{ ...branchTypeData }]]);
      });

      it('handles branches selection changes', async () => {
        const branchesData = { branches: ['main'] };
        await findBranchSelection().vm.$emit('changed', branchesData);
        expect(wrapper.emitted('changed')).toMatchObject([[{ ...branchesData }]]);
      });
    });

    describe('cadence', () => {
      it('emits changed event with daily schedule when daily is selected', async () => {
        createComponent();
        await findListbox().vm.$emit('select', 'daily');

        expect(wrapper.emitted('changed')).toHaveLength(1);
        expect(wrapper.emitted('changed')).toMatchObject([
          [{ type: 'daily', time_window: { value: 3600 } }],
        ]);
      });

      it('emits changed event with weekly schedule when weekly is selected', async () => {
        createComponent();
        await findListbox().vm.$emit('select', 'weekly');

        expect(wrapper.emitted('changed')).toHaveLength(1);
        expect(wrapper.emitted('changed')).toMatchObject([
          [{ type: 'weekly', days: 'monday', time_window: { value: 86400 } }],
        ]);
      });

      it('emits changed event with monthly schedule when monthly is selected', async () => {
        createComponent();
        await findListbox().vm.$emit('select', 'monthly');

        expect(wrapper.emitted('changed')).toHaveLength(1);
        expect(wrapper.emitted('changed')).toMatchObject([
          [{ type: 'monthly', days_of_month: [1], time_window: { value: 86400 } }],
        ]);
      });

      it('removes irrelevant properties when changing cadence type', async () => {
        createComponent({
          schedule: {
            type: 'daily',
            start_time: '12:00',
            days: 'friday',
            days_of_month: '15',
            time_window: { value: 3600 },
          },
        });

        await findListbox().vm.$emit('select', 'weekly');

        const emittedSchedule = wrapper.emitted('changed')[0][0];
        expect(emittedSchedule).toHaveProperty('days');
        expect(emittedSchedule).toHaveProperty('start_time');
        expect(emittedSchedule).not.toHaveProperty('days_of_month');
      });
    });

    describe('timezone', () => {
      it('handles timezone selection changes', async () => {
        const timezoneData = { identifier: 'America/Los_Angeles' };
        await findTimezoneDropdown().vm.$emit('input', timezoneData);
        expect(wrapper.emitted('changed')).toEqual([
          [expect.objectContaining({ timezone: timezoneData.identifier })],
        ]);
      });
    });

    describe('time dropdown', () => {
      it('emits changed event when time is selected', async () => {
        const timeDropdown = findTimeDropdown();
        await timeDropdown.vm.$emit('select', '10:00');
        expect(wrapper.emitted('changed')).toEqual([
          [expect.objectContaining({ start_time: '10:00' })],
        ]);
      });
    });

    describe('weekday dropdown', () => {
      it('emits changed event when days are selected', async () => {
        createComponent({ schedule: { type: 'weekly', days: ['monday'] } });
        const weekdayDropdown = findWeekdayDropdown();
        await weekdayDropdown.vm.$emit('select', ['monday', 'wednesday']);
        expect(wrapper.emitted('changed')).toEqual([
          [expect.objectContaining({ days: ['monday', 'wednesday'] })],
        ]);
      });
    });
  });
});
