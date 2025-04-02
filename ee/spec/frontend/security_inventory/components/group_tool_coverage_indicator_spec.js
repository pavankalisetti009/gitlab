import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GroupToolCoverageIndicator from 'ee/security_inventory/components/group_tool_coverage_indicator.vue';
import { SCANNERS } from 'ee/security_inventory/constants';

describe('GroupToolCoverageIndicator', () => {
  let wrapper;

  const findScannerBar = (scanner) => wrapper.findComponentByTestId(`${scanner}-bar`);
  const findScannerLabel = (scanner) => wrapper.findByTestId(`${scanner}-label`).text();

  const createComponent = (propsData) => {
    wrapper = shallowMountExtended(GroupToolCoverageIndicator, { propsData });
  };

  describe.each(SCANNERS)('$scanner bar', ({ scanner, label }) => {
    describe.each([17, 100, 0])('with %d% tool coverage', (value) => {
      it('passes correct segments prop to segmented bar, shows a label', () => {
        createComponent({ scanners: { [scanner]: value } });

        expect(findScannerBar(scanner).props()).toStrictEqual({
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

        const scannerLabel = findScannerLabel(scanner);

        expect(scannerLabel).toContain(label);
        expect(scannerLabel).toContain(`${value}%`);
      });
    });
  });
});
