import {
  getInitialDimensions,
  calculateDimensions,
} from 'ee/ai/duo_agentic_chat/utils/resize_utils';
import { WIDTH_OFFSET } from 'ee/ai/tanuki_bot/constants';
import {
  DEFAULT_WIDTH,
  DEFAULT_MIN_WIDTH,
  DEFAULT_MIN_HEIGHT,
} from 'ee/ai/duo_agentic_chat/constants';

describe('resize_utils', () => {
  const originalInnerWidth = window.innerWidth;
  const originalInnerHeight = window.innerHeight;

  // Default window dimensions
  const MOCK_INNER_WIDTH = 1920;
  const MOCK_INNER_HEIGHT = 1080;

  beforeEach(() => {
    window.innerWidth = MOCK_INNER_WIDTH;
    window.innerHeight = MOCK_INNER_HEIGHT;
  });

  afterEach(() => {
    window.innerWidth = originalInnerWidth;
    window.innerHeight = originalInnerHeight;
  });

  describe('getInitialDimensions', () => {
    it('returns initial dimension values', () => {
      const dimensions = getInitialDimensions();

      expect(dimensions).toEqual({
        width: DEFAULT_WIDTH,
        height: MOCK_INNER_HEIGHT,
        minWidth: DEFAULT_MIN_WIDTH,
        minHeight: DEFAULT_MIN_HEIGHT,
        left: null,
        top: null,
        maxHeight: null,
        maxWidth: null,
      });
    });
  });

  describe('calculateDimensions', () => {
    it('calculates dimensions with no parameters', () => {
      const dimensions = calculateDimensions();

      expect(dimensions).toEqual({
        width: DEFAULT_WIDTH,
        height: MOCK_INNER_HEIGHT,
        maxWidth: MOCK_INNER_WIDTH - WIDTH_OFFSET,
        maxHeight: MOCK_INNER_HEIGHT,
        top: MOCK_INNER_HEIGHT - MOCK_INNER_HEIGHT,
        left: MOCK_INNER_WIDTH - DEFAULT_WIDTH,
      });
    });

    it('calculates dimensions with custom width and height', () => {
      const MOCK_WIDTH = 700;
      const MOCK_HEIGHT = 900;

      const dimensions = calculateDimensions({
        width: MOCK_WIDTH,
        height: MOCK_HEIGHT,
      });

      expect(dimensions).toEqual({
        width: MOCK_WIDTH,
        height: MOCK_HEIGHT,
        maxWidth: MOCK_INNER_WIDTH - WIDTH_OFFSET,
        maxHeight: MOCK_INNER_HEIGHT,
        top: MOCK_INNER_HEIGHT - MOCK_HEIGHT,
        left: MOCK_INNER_WIDTH - MOCK_WIDTH,
      });
    });

    it('constrains width to maxWidth', () => {
      const MOCK_EXCESSIVE_WIDTH = 5000;

      const dimensions = calculateDimensions({
        width: MOCK_EXCESSIVE_WIDTH,
      });

      expect(dimensions.width).toBe(MOCK_INNER_WIDTH - WIDTH_OFFSET);
    });

    it('constrains height to maxHeight', () => {
      const MOCK_EXCESSIVE_HEIGHT = 5000;

      const dimensions = calculateDimensions({
        height: MOCK_EXCESSIVE_HEIGHT,
      });

      expect(dimensions.height).toBe(MOCK_INNER_HEIGHT);
    });

    it('uses currentWidth when width is not provided', () => {
      const MOCK_CURRENT_WIDTH = 800;
      const MOCK_HEIGHT = 600;

      const dimensions = calculateDimensions({
        currentWidth: MOCK_CURRENT_WIDTH,
        height: MOCK_HEIGHT,
      });

      expect(dimensions.width).toBe(MOCK_CURRENT_WIDTH);
    });

    it('uses currentHeight when height is not provided', () => {
      const MOCK_WIDTH = 700;
      const MOCK_CURRENT_HEIGHT = 900;

      const dimensions = calculateDimensions({
        width: MOCK_WIDTH,
        currentHeight: MOCK_CURRENT_HEIGHT,
      });

      expect(dimensions.height).toBe(MOCK_CURRENT_HEIGHT);
    });

    it('calculates top and left positions correctly', () => {
      const MOCK_SMALL_INNER_WIDTH = 1280;
      const MOCK_SMALL_INNER_HEIGHT = 720;
      const MOCK_WIDTH = 600;
      const MOCK_HEIGHT = 500;

      window.innerWidth = MOCK_SMALL_INNER_WIDTH;
      window.innerHeight = MOCK_SMALL_INNER_HEIGHT;

      const dimensions = calculateDimensions({
        width: MOCK_WIDTH,
        height: MOCK_HEIGHT,
      });

      expect(dimensions.top).toBe(MOCK_SMALL_INNER_HEIGHT - MOCK_HEIGHT);
      expect(dimensions.left).toBe(MOCK_SMALL_INNER_WIDTH - MOCK_WIDTH);
    });
  });
});
