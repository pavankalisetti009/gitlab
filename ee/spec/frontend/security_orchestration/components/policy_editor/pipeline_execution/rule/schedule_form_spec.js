import { shallowMount } from '@vue/test-utils';
import { GlCollapsibleListbox, GlSprintf } from '@gitlab/ui';
import ScheduleForm from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/schedule_form.vue';

describe('ScheduleForm', () => {
  let wrapper;
  const defaultSchedule = { type: 'daily', time_window: { value: 3600 } };

  const createComponent = (props = {}) => {
    wrapper = shallowMount(ScheduleForm, {
      propsData: { schedule: defaultSchedule, ...props },
      stubs: { GlSprintf },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  describe('rendering', () => {
    it('renders the component', () => {
      createComponent();
      expect(wrapper.exists()).toBe(true);
    });

    it('displays the correct message', () => {
      createComponent();
      expect(wrapper.text()).toContain('Schedule a pipeline on a  cadence for branches');
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
  });

  describe('updateCadence', () => {
    it('emits changed event with daily schedule when daily is selected', async () => {
      createComponent();
      await findListbox().vm.$emit('select', 'daily');

      expect(wrapper.emitted('changed')).toHaveLength(1);
      expect(wrapper.emitted('changed')).toMatchObject([
        [{ type: 'daily', start_time: '00:00', time_window: { value: 3600 } }],
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
        [{ type: 'monthly', days_of_month: '1', time_window: { value: 86400 } }],
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
      expect(emittedSchedule).not.toHaveProperty('start_time');
      expect(emittedSchedule).not.toHaveProperty('days_of_month');
    });
  });
});
