export const getMessagesToProcess = (messages, lastProcessedIndex) => {
  if (!messages || messages.length === 0) {
    return {
      toProcess: [],
      lastProcessedIndex: -1,
    };
  }

  const newLen = messages.length;

  // First run or log shrank (truncate / reset): process everything.
  const isFirstRunOrReset = lastProcessedIndex === -1;
  const lastLogLength = lastProcessedIndex + 1;
  let startIndex;
  if (isFirstRunOrReset) {
    startIndex = 0;
  } else if (newLen === lastLogLength) {
    startIndex = newLen - 1;
  } else {
    startIndex = lastProcessedIndex;
  }

  const toProcess = messages.slice(startIndex);

  return {
    toProcess,
    lastProcessedIndex: newLen - 1,
  };
};
