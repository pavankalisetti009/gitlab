const { relative } = require('node:path');
const { setTimeout: setTimeoutPromise } = require('node:timers/promises');
const axios = require('axios');
const FixtureCISequencer = require('./fixture_ci_sequencer');

const url = 'https://gitlab-org.gitlab.io/frontend/playground/jest-speed-reporter/vue3.json';

async function getFailedFilesAsAbsolutePaths(n = 0, maxRetries = 3) {
  try {
    const { data } = await axios.get(url, { timeout: 10_000 });
    return new Set(data.failedFiles);
  } catch (error) {
    console.error('\nFailed to fetch list of specs failing with @vue/compat: %s', error.message);

    if (n < maxRetries) {
      const waitMs = 5_000 * 2 ** n;
      console.error(`Waiting ${waitMs}ms to retry (${maxRetries - n} remaining)`);
      await setTimeoutPromise(waitMs);
      return getFailedFilesAsAbsolutePaths(n + 1);
    }

    throw error;
  }
}

class SkipSpecsBrokenInVueCompatFixtureCISequencer extends FixtureCISequencer {
  #failedSpecFilesPromise = getFailedFilesAsAbsolutePaths();

  async shard(tests, options) {
    const failedSpecFiles = await this.#failedSpecFilesPromise;

    const testsExcludingOnesThatFailInVueCompat = tests.filter(
      (test) => !failedSpecFiles.has(relative(test.context.config.rootDir, test.path)),
    );

    return super.shard(testsExcludingOnesThatFailInVueCompat, options);
  }
}

module.exports = SkipSpecsBrokenInVueCompatFixtureCISequencer;
