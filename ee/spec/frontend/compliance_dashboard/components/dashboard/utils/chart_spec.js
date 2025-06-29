import {
  getColors,
  getLegendConfig,
  getTooltipConfig,
} from 'ee/compliance_dashboard/components/dashboard/utils/chart';
import { GL_DARK, GL_LIGHT } from '~/constants';

describe('chart utility functions', () => {
  describe('getColors', () => {
    it('returns expected structure', () => {
      expect(Object.keys(getColors(GL_LIGHT)).sort()).toStrictEqual(
        ['textColor', 'blueDataColor', 'orangeDataColor', 'magentaDataColor', 'ticksColor'].sort(),
      );
    });

    it('adopts to color scheme change', () => {
      expect(getColors(GL_LIGHT)).not.toEqual(getColors(GL_DARK));
    });
  });

  describe('getLegendConfig', () => {
    it('returns expected structure', () => {
      const COLOR = 'test';
      expect(getLegendConfig(COLOR)).toEqual(
        expect.objectContaining({
          orient: 'vertical',
          textStyle: expect.objectContaining({
            color: COLOR,
          }),
        }),
      );
    });
  });

  describe('getTooltipConfig', () => {
    it('returns expected structure', () => {
      expect(Object.keys(getTooltipConfig()).sort()).toStrictEqual(
        ['padding', 'borderWidth', 'textStyle'].sort(),
      );
    });
  });
});
