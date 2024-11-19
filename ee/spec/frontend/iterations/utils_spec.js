import {
  getIterationPeriod,
  groupByIterationCadences,
  groupOptionsByIterationCadences,
} from 'ee/iterations/utils';
import { mockIterationsWithCadences, mockIterationsWithoutCadences } from './mock_data';

describe('getIterationPeriod', () => {
  it.each`
    scenario                                                                                                       | usedInIssue | startYear | dueYear | currentYear | expected
    ${'formatted for use in an issue and the start and due years are different'}                                   | ${true}     | ${2021}   | ${2022} | ${2024}     | ${'Feb 10, 2021 - Feb 17, 2022'}
    ${'formatted for use in an issue and the start, due and current years are all the same'}                       | ${true}     | ${2021}   | ${2021} | ${2021}     | ${'Feb 10 - Feb 17'}
    ${'formatted for use in an issue and the start and due years are the same, but they are not the current year'} | ${true}     | ${2021}   | ${2021} | ${2024}     | ${'Feb 10 - Feb 17, 2021'}
    ${'the start and due years are different'}                                                                     | ${false}    | ${2021}   | ${2022} | ${2024}     | ${'Feb 10, 2021 - Feb 17, 2022'}
    ${'the start and due years are the same'}                                                                      | ${false}    | ${2021}   | ${2021} | ${2024}     | ${'Feb 10 - Feb 17, 2021'}
  `(
    'returns correctly formatted iteration period when $scenario',
    ({ startYear, dueYear, currentYear, usedInIssue, expected }) => {
      const iterationDates = {
        startDate: new Date(startYear, 1, 10),
        dueDate: new Date(dueYear, 1, 17),
      };
      Date.now = jest.fn(() => new Date(currentYear, 1, 10));

      expect(getIterationPeriod(iterationDates, usedInIssue)).toBe(expected);
    },
  );
});

describe('groupByIterationCadences', () => {
  const period = 'Nov 23, 2021 - Nov 30, 2021';
  const expected = [
    {
      id: 1,
      title: 'cadence 1',
      iterations: [
        { id: 1, title: 'iteration 1', period },
        { id: 4, title: 'iteration 4', period },
      ],
    },
    {
      id: 2,
      title: 'cadence 2',
      iterations: [
        { id: 2, title: 'iteration 2', period },
        { id: 3, title: 'iteration 3', period },
      ],
    },
  ];

  it('groups iterations by cadence', () => {
    expect(groupByIterationCadences(mockIterationsWithCadences)).toStrictEqual(expected);
  });

  it('returns empty array when iterations do not have cadences', () => {
    expect(groupByIterationCadences(mockIterationsWithoutCadences)).toEqual([]);
  });

  it('returns empty array when passed an empty array', () => {
    expect(groupByIterationCadences([])).toEqual([]);
  });
});

describe('groupOptionsByIterationCadences', () => {
  const text = 'Nov 23, 2021 - Nov 30, 2021';
  const expected = [
    {
      text: 'cadence 1',
      options: [
        { value: 1, title: 'iteration 1', text },
        { value: 4, title: 'iteration 4', text },
      ],
    },
    {
      text: 'cadence 2',
      options: [
        { value: 2, title: 'iteration 2', text },
        { value: 3, title: 'iteration 3', text },
      ],
    },
  ];

  it('groups iterations by cadence', () => {
    expect(groupOptionsByIterationCadences(mockIterationsWithCadences)).toStrictEqual(expected);
  });

  it('returns empty array when iterations do not have cadences', () => {
    expect(groupOptionsByIterationCadences(mockIterationsWithoutCadences)).toEqual([]);
  });

  it('returns empty array when passed an empty array', () => {
    expect(groupOptionsByIterationCadences([])).toEqual([]);
  });
});
