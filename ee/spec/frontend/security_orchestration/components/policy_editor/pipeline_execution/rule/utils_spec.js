import {
  determineTimeUnit,
  secondsToValue,
  timeUnitToSeconds,
  updateScheduleCadence,
  TIME_UNITS,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/utils';

describe('Pipeline execution rule utils', () => {
  describe('time unit utilities', () => {
    describe('timeUnitToSeconds', () => {
      it('converts hours to seconds correctly', () => {
        expect(timeUnitToSeconds(2, TIME_UNITS.HOUR)).toBe(7200);
      });

      it('converts days to seconds correctly', () => {
        expect(timeUnitToSeconds(1, TIME_UNITS.DAY)).toBe(86400);
      });

      it('handles seconds correctly', () => {
        expect(timeUnitToSeconds(30, TIME_UNITS.MINUTE)).toBe(1800);
      });
    });

    describe('secondsToValue', () => {
      it('converts seconds to minutes correctly', () => {
        expect(secondsToValue(60, TIME_UNITS.MINUTE)).toBe(1);
      });

      it('converts seconds to hours correctly', () => {
        expect(secondsToValue(7200, TIME_UNITS.HOUR)).toBe(2);
      });

      it('converts seconds to days correctly', () => {
        expect(secondsToValue(86400, TIME_UNITS.DAY)).toBe(1);
      });
    });

    describe('determineTimeUnit', () => {
      it('selects days for values divisible by 86400', () => {
        expect(determineTimeUnit(86400)).toBe(TIME_UNITS.DAY);
        expect(determineTimeUnit(172800)).toBe(TIME_UNITS.DAY);
      });

      it('selects hours for values divisible by 3600 but not 86400', () => {
        expect(determineTimeUnit(3600)).toBe(TIME_UNITS.HOUR);
        expect(determineTimeUnit(7200)).toBe(TIME_UNITS.HOUR);
      });

      it('selects minute for other values', () => {
        expect(determineTimeUnit(60)).toBe(TIME_UNITS.MINUTE);
        expect(determineTimeUnit(120)).toBe(TIME_UNITS.MINUTE);
      });

      it('defaults to minutes for zero or negative values', () => {
        expect(determineTimeUnit(0)).toBe(TIME_UNITS.MINUTE);
        expect(determineTimeUnit(-60)).toBe(TIME_UNITS.MINUTE);
      });
    });
  });

  describe('updateScheduleCadence', () => {
    const baseSchedule = {
      start_time: '00:00',
      time_window: { value: 3600, distribution: 'random' },
      timezone: 'America/New_York',
    };

    const dailySchedule = {
      type: 'daily',
      ...baseSchedule,
    };

    const weeklySchedule = {
      type: 'weekly',
      days: 'monday',
      ...baseSchedule,
    };

    const monthlySchedule = {
      type: 'monthly',
      days_of_month: [1],
      ...baseSchedule,
    };

    it('updates to daily cadence correctly', () => {
      expect(updateScheduleCadence({ schedule: weeklySchedule, cadence: 'daily' })).toEqual(
        expect.objectContaining({
          ...dailySchedule,
          time_window: { value: 60, distribution: 'random' },
        }),
      );
    });

    it('updates to weekly cadence correctly', () => {
      expect(updateScheduleCadence({ schedule: monthlySchedule, cadence: 'weekly' })).toEqual(
        expect.objectContaining({
          ...weeklySchedule,
          time_window: { value: 86400, distribution: 'random' },
        }),
      );
    });

    it('updates to monthly cadence correctly', () => {
      expect(updateScheduleCadence({ schedule: dailySchedule, cadence: 'monthly' })).toEqual(
        expect.objectContaining({
          ...monthlySchedule,
          time_window: { value: 86400, distribution: 'random' },
        }),
      );
    });

    it('removes irrelevant properties when changing cadence type', () => {
      const result = updateScheduleCadence({
        schedule: baseSchedule,
        cadence: 'weekly',
      });

      expect(result).toHaveProperty('days');
      expect(result).not.toHaveProperty('days_of_month');
    });

    it('preserves additional properties not related to cadence', () => {
      const scheduleWithExtra = {
        ...baseSchedule,
        custom_property: 'value',
        another_property: 123,
      };

      const result = updateScheduleCadence({
        schedule: scheduleWithExtra,
        cadence: 'weekly',
      });

      expect(result.custom_property).toBe('value');
      expect(result.another_property).toBe(123);
    });
  });
});
