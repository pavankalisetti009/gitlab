import { dateToYearMonthDate, newDate } from '~/lib/utils/datetime_utility';

const formatMonthData = (cur) => {
  const date = newDate(cur.monthIso8601);
  const formattedDate = dateToYearMonthDate(date);

  return {
    date,
    ...formattedDate,
    ...cur,
  };
};

export const getUsageDataByYearAsArray = (ciMinutesUsage) => {
  return ciMinutesUsage.reduce((acc, cur) => {
    const formattedData = formatMonthData(cur);

    if (acc[formattedData.year] != null) {
      acc[formattedData.year].push(formattedData);
    } else {
      acc[formattedData.year] = [formattedData];
    }
    return acc;
  }, {});
};

export const getUsageDataByYearByMonthAsObject = (ciMinutesUsage) => {
  return ciMinutesUsage.reduce((acc, cur) => {
    const formattedData = formatMonthData(cur);

    if (!acc[formattedData.year]) {
      acc[formattedData.year] = {};
    }

    acc[formattedData.year][formattedData.date.getMonth()] = formattedData;
    return acc;
  }, {});
};
