import { WIDTH_OFFSET } from 'ee/ai/tanuki_bot/constants';
import { DEFAULT_WIDTH, DEFAULT_MIN_WIDTH, DEFAULT_MIN_HEIGHT } from '../constants';

export function getInitialDimensions() {
  return {
    width: DEFAULT_WIDTH,
    height: window.innerHeight,
    minWidth: DEFAULT_MIN_WIDTH,
    minHeight: DEFAULT_MIN_HEIGHT,
    left: null,
    top: null,
    maxHeight: null,
    maxWidth: null,
  };
}

export function calculateDimensions({
  width = null,
  height = null,
  currentWidth = DEFAULT_WIDTH,
  currentHeight = null,
} = {}) {
  const maxWidth = window.innerWidth - WIDTH_OFFSET;
  const maxHeight = window.innerHeight;

  const newWidth = Math.min(width || currentWidth, maxWidth);
  const newHeight = Math.min(height || (currentHeight ?? window.innerHeight), maxHeight);
  const top = window.innerHeight - newHeight;
  const left = window.innerWidth - newWidth;

  return {
    width: newWidth,
    height: newHeight,
    maxWidth,
    maxHeight,
    top,
    left,
  };
}
