import { differenceWith, isEqual } from 'lodash';
import { linesPadding } from 'ee/vue_shared/components/code_flow/utils/constants';
import { splitByLineBreaks } from '~/vue_shared/components/source_viewer/workers/highlight_utils';

/**
 * Sorts and merges code blocks based on their start and end lines.
 * @param {Array} codeBlocks - An array of code block objects. Each object should have
 *                             the following properties:
 *                             - blockStartLine {number}: The starting line of the block
 *                             - blockEndLine {number}: The ending line of the block
 *                             - highlightInfo {Array}: An array of highlight information
 * @returns {Array} An array of sorted and merged code block objects. Each object in the
 *                  returned array will have the same structure as the input, but with
 *                  potentially merged blocks and combined highlightInfo.
 */
export const sortCodeBlocks = (codeBlocks) => {
  // Ensure the method is pure by not mutating the original array
  const updatedCodeBlock = [...codeBlocks].sort((a, b) => a.blockStartLine - b.blockStartLine);
  return updatedCodeBlock.reduce(
    (acc, block) => {
      const lastMergedBlock = acc.at(-1);
      if (block.blockStartLine <= lastMergedBlock.blockEndLine + 1) {
        lastMergedBlock.blockEndLine = Math.max(lastMergedBlock.blockEndLine, block.blockEndLine);
        const uniqueHighlightInfo = differenceWith(
          block.highlightInfo,
          lastMergedBlock.highlightInfo,
          isEqual,
        );
        lastMergedBlock.highlightInfo.push(...uniqueHighlightInfo);
      } else {
        acc.push(block);
      }
      return acc;
    },
    [updatedCodeBlock[0]],
  );
};

/**
 * Updates and merges code blocks, adding step numbers to highlight information.
 * @param {Array} codeBlocks - An array of code block objects. Each object should have a
 *                             'highlightInfo' property which is an array of highlight items.
 * @returns {Array} An array of updated code block objects. Each object in the returned array
 *                  will have the same structure as the input, but with merged blocks and
 *                  updated highlight information. If the input array is empty, an empty array
 *                  is returned.
 */
export const updateCodeBlocks = (codeBlocks) => {
  if (!codeBlocks.length) {
    return [];
  }

  const mergedBlocks = sortCodeBlocks(codeBlocks);

  return mergedBlocks.map((block) => {
    const updatedHighlightInfo = block.highlightInfo.map((item) => {
      return {
        ...item,
        stepNumber: item.index + 1,
      };
    });

    return {
      ...block,
      highlightInfo: updatedHighlightInfo,
    };
  });
};

/**
 * Creates a mapping of line numbers to highlight information based on code blocks.
 * @param {Array} codeBlocks - An array of code block objects. Each object should have
 *                             a 'highlightInfo' property, which is an array of objects
 *                             containing at least 'startLine' and optionally 'endLine'.
 * @returns {Object} An object mapping line numbers to their respective highlight information.
 *                   Each key is a line number, and each value is the highlight info object
 *                   that corresponds to that line.
 */
export const updateLinesToMarker = (codeBlocks) => {
  return codeBlocks.reduce((acc, { highlightInfo }) => {
    highlightInfo.forEach((item) => {
      const endLine = item.endLine || item.startLine;
      for (let k = item.startLine; k <= endLine; k += 1) {
        (acc[k] || (acc[k] = [])).push(item);
      }
    });
    return acc;
  }, {});
};

/**
 * Normalizes code flow information from details.
 * @param {Object} details - The details object containing code flow items.
 * @returns {Object} Normalized code flows grouped by file name.
 */
export const normalizeCodeFlowsInfo = (details) => {
  const firstCodeFlow = details?.items[0] || [];
  return firstCodeFlow.reduce((acc, curr, index) => {
    const { fileLocation } = curr;
    const name = fileLocation.fileName;
    if (!acc[name]) {
      acc[name] = [];
    }
    acc[name].push({ index, fileLocation });
    return acc;
  }, {});
};

/**
 * Creates source block highlight information for a single block.
 * @param {number} index - The index of the block.
 * @param {Object} fileLocation - The file location information.
 * @param {string} rawTextBlob - The raw text content of the file.
 * @returns {Object} Source block highlight information.
 */
export const createSourceBlockHighlightInfo = (index, fileLocation, rawTextBlob) => {
  const fileLen = splitByLineBreaks(rawTextBlob).length || 0;
  const calcStartLine = fileLocation.lineStart - linesPadding;
  const calcEndLine = (fileLocation.lineEnd || fileLocation.lineStart) + linesPadding;
  return {
    blockStartLine: calcStartLine > 0 ? calcStartLine : 1,
    blockEndLine: calcEndLine > fileLen ? fileLen : calcEndLine,
    highlightInfo: [
      {
        index,
        startLine: fileLocation.lineStart,
        endLine: fileLocation.lineEnd,
      },
    ],
  };
};

/**
 * Creates highlight sources information from normalized code flows.
 * @param {Object} normalizedCodeFlows - Normalized code flows grouped by file name.
 * @param {Object} rawTextBlobs - Raw text content of files.
 * @returns {Object} Highlight sources information grouped by file name.
 */
export const createHighlightSourcesInfo = (normalizedCodeFlows, rawTextBlobs) => {
  if (!normalizedCodeFlows || !rawTextBlobs) return {};
  return Object.entries(normalizedCodeFlows).reduce((acc, [fileName, flows]) => {
    acc[fileName] = flows.map(({ index, fileLocation }) =>
      createSourceBlockHighlightInfo(index, fileLocation, rawTextBlobs[fileLocation.fileName]),
    );
    return acc;
  }, {});
};
