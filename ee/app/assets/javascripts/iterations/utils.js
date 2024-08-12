import { formatDate } from '~/lib/utils/datetime_utility';

const PERIOD_DATE_FORMAT_WITH_YEAR = 'mmm d, yyyy';

const PERIOD_DATE_FORMAT_SHORT = 'mmm d';

// eslint-disable-next-line max-params
const getStartAndDueDateFormats = (startDate, dueDate, usedInIssue, full) => {
  const currentYear = new Date(Date.now()).getFullYear();
  const startDateYear = new Date(startDate).getFullYear();
  const dueDateYear = new Date(dueDate).getFullYear();
  if (full) {
    return {
      startDateFormat: PERIOD_DATE_FORMAT_WITH_YEAR,
      dueDateFormat: PERIOD_DATE_FORMAT_WITH_YEAR,
    };
  }
  // In issue lists and boards...
  if (usedInIssue) {
    // is start year isn't the same as due year, show both years
    if (startDateYear !== dueDateYear) {
      return {
        startDateFormat: PERIOD_DATE_FORMAT_WITH_YEAR,
        dueDateFormat: PERIOD_DATE_FORMAT_WITH_YEAR,
      };
    }
    // if start and due years are the same but it's not the current year, show due year
    if (startDateYear === dueDateYear && dueDateYear !== currentYear) {
      return {
        startDateFormat: PERIOD_DATE_FORMAT_SHORT,
        dueDateFormat: PERIOD_DATE_FORMAT_WITH_YEAR,
      };
    }
    // if start and due years are the same and it's the current year, don't show due year
    if (startDateYear === dueDateYear && dueDateYear === currentYear) {
      return {
        startDateFormat: PERIOD_DATE_FORMAT_SHORT,
        dueDateFormat: PERIOD_DATE_FORMAT_SHORT,
      };
    }
  }
  // if it's a use outside issue lists and boards...

  // if start and due years are not the same, show both years
  if (startDateYear !== dueDateYear) {
    return {
      startDateFormat: PERIOD_DATE_FORMAT_WITH_YEAR,
      dueDateFormat: PERIOD_DATE_FORMAT_WITH_YEAR,
    };
  }

  // in all other cases
  return {
    startDateFormat: PERIOD_DATE_FORMAT_SHORT,
    dueDateFormat: PERIOD_DATE_FORMAT_WITH_YEAR,
  };
};

/**
 * The first argument is two date strings in formatted in ISO 8601 (YYYY-MM-DD)
 * If the startDate year is the same as the current year, the start date
 * year is omitted.
 *
 * The second argument is a boolean switch that determines whether the
 * iteration period should be formatted for use in an issue or not. There are
 * intended design differences in the way the period is formatted for uses like
 * a board issue card or the issue sidebar. This argument is optional and
 * defaults to false.
 *
 * @returns {string}
 *
 * ex. "Oct 1, 2021 - Oct 10, 2022" if start and due dates have different years, regardless of current year.
 *
 * "Oct 1 - Oct 10, 2021" if start and due dates are both in 2021, current year === 2021 and `usedInIssue` is false.
 *
 * "Oct 1 - Oct 10" if start and due dates are both 2021, current year === 2021 and `usedInIssue` is true.
 */
export function getIterationPeriod({ startDate, dueDate }, usedInIssue = false, full = false) {
  const { startDateFormat, dueDateFormat } = getStartAndDueDateFormats(
    startDate,
    dueDate,
    usedInIssue,
    full,
  );

  const start = formatDate(startDate, startDateFormat, true);
  const due = formatDate(dueDate, dueDateFormat, true);
  return `${start} - ${due}`;
}

/**
 * Group a list of iterations by cadence.
 *
 * @param iterations A list of iterations
 * @return {Array} A list of cadences
 */
export function groupByIterationCadences(iterations) {
  const cadences = [];
  iterations.forEach((iteration) => {
    if (!iteration.iterationCadence) {
      return;
    }
    const { title, id } = iteration.iterationCadence;
    const cadenceIteration = {
      id: iteration.id,
      title: iteration.title,
      period: getIterationPeriod(iteration, null, true),
    };
    const cadence = cadences.find((c) => c.title === title);
    if (cadence) {
      cadence.iterations.push(cadenceIteration);
    } else {
      cadences.push({ title, iterations: [cadenceIteration], id });
    }
  });
  return cadences;
}

export function groupOptionsByIterationCadences(iterations) {
  const cadences = [];
  iterations.forEach((iteration) => {
    if (!iteration.iterationCadence) {
      return;
    }
    const { title } = iteration.iterationCadence;
    const cadenceIteration = {
      value: iteration.id,
      title: iteration.title,
      text: getIterationPeriod(iteration, null, true),
    };
    const cadence = cadences.find((c) => c.text === title);
    if (cadence) {
      cadence.options.push(cadenceIteration);
    } else {
      cadences.push({ text: title, options: [cadenceIteration] });
    }
  });
  return cadences;
}
