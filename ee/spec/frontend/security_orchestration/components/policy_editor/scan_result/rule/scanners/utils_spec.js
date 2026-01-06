import {
  normalizeVulnerabilityStates,
  enableStatusFilter,
  enableAttributeFilter,
  removePropertyFromPayload,
  getAgeTooltip,
  selectEmptyArrayWhenAllSelected,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/utils';

import {
  AGE,
  AGE_TOOLTIP_NO_PREVIOUSLY_EXISTING_VULNERABILITY,
  AGE_TOOLTIP_MAXIMUM_REACHED,
  DEFAULT_VULNERABILITY_STATES,
  NEWLY_DETECTED,
  PREVIOUSLY_EXISTING,
  FIX_AVAILABLE,
  FALSE_POSITIVE,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';

describe('scan filter utils', () => {
  describe('normalizeVulnerabilityStates', () => {
    it.each`
      states                                                           | output
      ${{ [NEWLY_DETECTED]: [], [PREVIOUSLY_EXISTING]: [] }}           | ${null}
      ${{ [NEWLY_DETECTED]: ['new'], [PREVIOUSLY_EXISTING]: [] }}      | ${['new']}
      ${{ [NEWLY_DETECTED]: [], [PREVIOUSLY_EXISTING]: ['existing'] }} | ${['existing']}
    `('returns normalized states', ({ states, output }) => {
      expect(normalizeVulnerabilityStates(states)).toEqual(output);
    });

    it('returns empty array when states match defaults', () => {
      const states = {
        [NEWLY_DETECTED]: DEFAULT_VULNERABILITY_STATES.filter((s) => s.startsWith('new')),
        [PREVIOUSLY_EXISTING]: DEFAULT_VULNERABILITY_STATES.filter((s) => !s.startsWith('new')),
      };

      expect(normalizeVulnerabilityStates(states)).toEqual([]);
    });

    it('handles missing keys', () => {
      expect(normalizeVulnerabilityStates({})).toBeNull();
    });
  });

  describe('enableStatusFilter', () => {
    it('enables newly detected when none present', () => {
      const filters = {};

      expect(enableStatusFilter(filters)).toEqual({
        [NEWLY_DETECTED]: true,
      });
    });

    it('enables previously existing when newly detected already enabled', () => {
      const filters = {
        [NEWLY_DETECTED]: true,
      };

      expect(enableStatusFilter(filters)).toEqual({
        [NEWLY_DETECTED]: true,
        [PREVIOUSLY_EXISTING]: true,
      });
    });
  });

  describe('enableAttributeFilter', () => {
    it.each`
      attributes                    | output
      ${{ [FIX_AVAILABLE]: true }}  | ${{ [FIX_AVAILABLE]: true, [FALSE_POSITIVE]: true }}
      ${{ [FALSE_POSITIVE]: true }} | ${{ [FIX_AVAILABLE]: true, [FALSE_POSITIVE]: true }}
    `('enables attribute filters when attribute filter is selected', ({ attributes, output }) => {
      expect(enableAttributeFilter(attributes)).toEqual(output);
    });
  });

  describe('removePropertyFromPayload', () => {
    it.each`
      payload                       | key       | output
      ${{ test: true }}             | ${'test'} | ${{}}
      ${{ test: true }}             | ${'noop'} | ${{ test: true }}
      ${{ test: true, foo: 'bar' }} | ${'test'} | ${{ foo: 'bar' }}
      ${{ test: true }}             | ${''}     | ${{ test: true }}
    `('removes property from payload', ({ payload, key, output }) => {
      expect(removePropertyFromPayload(payload, key)).toEqual(output);
    });
  });

  describe('getAgeTooltip', () => {
    const filter = {
      value: AGE,
      tooltip: {
        [AGE_TOOLTIP_NO_PREVIOUSLY_EXISTING_VULNERABILITY]: 'no previous',
        [AGE_TOOLTIP_MAXIMUM_REACHED]: 'max reached',
      },
    };

    it.each`
      vulnerabilityStates                        | expected
      ${{ [PREVIOUSLY_EXISTING]: [] }}           | ${'no previous'}
      ${{ [PREVIOUSLY_EXISTING]: ['existing'] }} | ${'max reached'}
    `('returns correct tooltip for AGE filter', ({ vulnerabilityStates, expected }) => {
      expect(getAgeTooltip(filter, vulnerabilityStates)).toBe(expected);
    });

    it.each`
      filterValue  | expected
      ${'other'}   | ${''}
      ${undefined} | ${''}
    `('returns empty string for unsupported filter values', ({ filterValue, expected }) => {
      expect(getAgeTooltip({ value: filterValue }, {})).toBe(expected);
    });
  });

  describe('selectEmptyArrayWhenAllSelected', () => {
    it.each`
      values        | allCount | output
      ${['a', 'b']} | ${2}     | ${[]}
      ${['a']}      | ${2}     | ${['a']}
      ${[]}         | ${2}     | ${[]}
    `('returns correct array', ({ values, allCount, output }) => {
      expect(selectEmptyArrayWhenAllSelected(values, allCount)).toEqual(output);
    });

    it.each`
      values       | allCount | output
      ${null}      | ${2}     | ${[]}
      ${['a']}     | ${NaN}   | ${[]}
      ${'invalid'} | ${2}     | ${[]}
    `('handles invalid inputs', ({ values, allCount, output }) => {
      expect(selectEmptyArrayWhenAllSelected(values, allCount)).toEqual(output);
    });
  });
});
