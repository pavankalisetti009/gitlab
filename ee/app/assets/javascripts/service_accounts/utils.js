import { getDateInFuture } from '~/lib/utils/datetime_utility';

/**
 * Return the default expiration date.
 * If the maximum date is sooner than the 30 days we use the maximum date, otherwise default to 30 days.
 * The maximum date can be set by admins only in EE.
 * @param {Date} [maxDate]
 */
export function defaultDate(maxDate) {
  const OFFSET_DAYS = 30;
  const thirtyDaysFromNow = getDateInFuture(new Date(), OFFSET_DAYS);
  if (maxDate && maxDate < thirtyDaysFromNow) {
    return maxDate;
  }
  return thirtyDaysFromNow;
}
