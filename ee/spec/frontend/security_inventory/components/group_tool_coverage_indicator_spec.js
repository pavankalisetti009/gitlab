import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GroupToolCoverageIndicator from 'ee/security_inventory/components/group_tool_coverage_indicator.vue';
import { SCANNER_POPOVER_GROUPS, SCANNER_TYPES } from 'ee/security_inventory/constants';

describe('GroupToolCoverageIndicator', () => {
  let wrapper;

  const findScannerBar = (scanner) => wrapper.findComponentByTestId(`${scanner}-bar`);
  const findScannerLabel = (scanner) => wrapper.findByTestId(`${scanner}-label`).text();

  const createComponent = (propsData) => {
    wrapper = shallowMountExtended(GroupToolCoverageIndicator, { propsData });
  };

  const scanners = Object.keys(SCANNER_POPOVER_GROUPS).map((key) => ({
    key,
    label: SCANNER_TYPES[key].textLabel,
  }));

  describe.each(scanners)('$label bar', ({ label, key }) => {
    describe.each([17, 100, 0])('with %d% tool coverage', (value) => {
      it('passes correct segments prop to segmented bar, shows a label', () => {
        createComponent({ scanners: { [key]: value } });
        expect(findScannerBar(key).props()).toStrictEqual({
          segments: [
            {
              class: 'gl-bg-green-500',
              count: value,
            },
            {
              class: 'gl-bg-neutral-200',
              count: 100 - value,
            },
          ],
        });

        const scannerLabel = findScannerLabel(key);
        expect(scannerLabel).toContain(label);
        expect(scannerLabel).toContain(`${value}%`);
      });
    });
  });
});
