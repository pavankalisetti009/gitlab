import { defaultDate } from 'ee/service_accounts/utils';

// Current date, `new Date()`, for these tests is 2020-07-06
describe('defaultDate', () => {
  describe('when max date is not present', () => {
    it('defaults to 30 days from now', () => {
      expect(defaultDate().getTime()).toBe(new Date('2020-08-05').getTime());
    });
  });

  describe('when max date is present', () => {
    it('defaults to 30 days from now if max date is later', () => {
      const maxDate = new Date('2021-01-01');
      expect(defaultDate(maxDate).getTime()).toBe(new Date('2020-08-05').getTime());
    });

    it('defaults max date if max date is sooner than 30 days', () => {
      const maxDate = new Date('2020-08-01');
      expect(defaultDate(maxDate).getTime()).toBe(new Date('2020-08-01').getTime());
    });
  });
});
