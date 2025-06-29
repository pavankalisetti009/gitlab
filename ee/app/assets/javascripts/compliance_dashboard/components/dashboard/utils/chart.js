import {
  GL_TEXT_COLOR_DEFAULT,
  DATA_VIZ_BLUE_500,
  DATA_VIZ_ORANGE_400,
  DATA_VIZ_MAGENTA_500,
  GRAY_900,
} from '@gitlab/ui/src/tokens/build/js/tokens';
import {
  GL_TEXT_COLOR_DEFAULT as GL_TEXT_COLOR_DEFAULT_DARK,
  GRAY_900 as GRAY_900_DARK,
} from '@gitlab/ui/src/tokens/build/js/tokens.dark';

import { GL_DARK } from '~/constants';

export function getColors(colorScheme) {
  const textColor = colorScheme === GL_DARK ? GL_TEXT_COLOR_DEFAULT_DARK : GL_TEXT_COLOR_DEFAULT;
  return {
    textColor,
    blueDataColor: DATA_VIZ_BLUE_500,
    orangeDataColor: DATA_VIZ_ORANGE_400,
    magentaDataColor: DATA_VIZ_MAGENTA_500,
    ticksColor: colorScheme === GL_DARK ? GRAY_900_DARK : GRAY_900,
  };
}

export const getLegendConfig = (textColor) => ({
  top: 0,
  left: 0,
  orient: 'vertical',
  itemWidth: 14,
  itemHeight: 14,
  itemGap: 8,
  textStyle: {
    fontSize: 12,
    color: textColor,
    fontWeight: 'bold',
  },
});

export const getTooltipConfig = (textColor) => ({
  padding: 0,
  borderWidth: 0,
  textStyle: {
    fontSize: 12,
    color: textColor,
  },
});
