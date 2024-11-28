#!/usr/bin/env node

const { spawnSync } = require('node:child_process');
const { readFile, open, stat } = require('node:fs/promises');
const { join, relative } = require('node:path');
const defaultChalk = require('chalk');
const { getLocalQuarantinedFiles } = require('./jest_vue3_quarantine_utils');

// Always use basic color output
const chalk = new defaultChalk.constructor({ level: 1 });

const JEST_JSON_OUTPUT = './jest_results.json';

let quarantinedFiles;
let filesThatChanged;

async function parseResults() {
  const root = join(__dirname, '..', '..');

  let results;
  try {
    results = JSON.parse(await readFile(JEST_JSON_OUTPUT, 'UTF-8'));
  } catch (e) {
    console.warn(e);
    // No JUnit report exists, or there was a parsing error. Either way, we
    // should not block the MR.
    return [];
  }

  return results.testResults.reduce((acc, { name, status }) => {
    if (status === 'passed') {
      acc.push(relative(root, name));
    }

    return acc;
  }, []);
}

function reportSpecsShouldBeUnquarantined(files) {
  const docsLink =
    // eslint-disable-next-line no-restricted-syntax
    'https://docs.gitlab.com/ee/development/testing_guide/testing_vue3.html#quarantine-list';
  console.warn(' ');
  console.warn(
    `The following ${files.length} spec files either now pass under Vue 3, or no longer exist, and so must be removed from quarantine:`,
  );
  console.warn(' ');
  console.warn(files.join('\n'));
  console.warn(' ');
  console.warn(
    chalk.red(
      `To fix this job, remove the files listed above from the file ${chalk.underline('scripts/frontend/quarantined_vue3_specs.txt')}.`,
    ),
  );
  console.warn(`For more information, please see ${docsLink}.`);
}

async function changedFiles() {
  const { RSPEC_CHANGED_FILES_PATH, RSPEC_MATCHING_JS_FILES_PATH } = process.env;

  const files = await Promise.all(
    [RSPEC_CHANGED_FILES_PATH, RSPEC_MATCHING_JS_FILES_PATH].map((path) =>
      readFile(path, 'UTF-8').then((content) => content.split(/\s+/).filter(Boolean)),
    ),
  );

  return files.flat();
}

function intersection(a, b) {
  const result = new Set();

  for (const element of a) {
    if (b.has(element)) result.add(element);
  }

  return result;
}

async function getRemovedQuarantinedSpecs() {
  const removedQuarantinedSpecs = [];

  for (const file of intersection(filesThatChanged, quarantinedFiles)) {
    try {
      // eslint-disable-next-line no-await-in-loop
      await stat(file);
    } catch (e) {
      if (e.code === 'ENOENT') removedQuarantinedSpecs.push(file);
    }
  }

  return removedQuarantinedSpecs;
}

async function main() {
  filesThatChanged = await changedFiles();
  quarantinedFiles = new Set(await getLocalQuarantinedFiles());
  const jestStdout = (await open('jest_stdout', 'w')).createWriteStream();
  const jestStderr = (await open('jest_stderr', 'w')).createWriteStream();

  console.log('Running quarantined specs...');

  // Note: we don't care what Jest's exit code is.
  //
  // If it's zero, then either:
  //   - all specs passed, or
  //   - no specs were run.
  //
  // Both situations are handled later.
  //
  // If it's non-zero, then either:
  //   - one or more specs failed (which is expected!), or
  //   - there was some unknown error. We shouldn't block MRs in this case.
  spawnSync(
    'node_modules/.bin/jest',
    [
      '--config',
      'jest.config.js',
      '--ci',
      '--findRelatedTests',
      ...filesThatChanged,
      '--passWithNoTests',
      // Explicitly have one shard, so that the `shard` method of the sequencer is called.
      '--shard=1/1',
      '--testSequencer',
      './scripts/frontend/check_jest_vue3_quarantine_sequencer.js',
      '--logHeapUsage',
      '--json',
      `--outputFile=${JEST_JSON_OUTPUT}`,
    ],
    {
      stdio: ['inherit', jestStdout, jestStderr],
      env: {
        ...process.env,
        VUE_VERSION: '3',
      },
    },
  );

  const passed = await parseResults();
  const removedQuarantinedSpecs = await getRemovedQuarantinedSpecs();
  const filesToReport = [...passed, ...removedQuarantinedSpecs];

  if (filesToReport.length === 0) {
    // No tests ran, or there was some unexpected error. Either way, exit
    // successfully.
    return;
  }

  process.exitCode = 1;
  reportSpecsShouldBeUnquarantined(filesToReport);
}

main().catch((e) => {
  // Don't block on unexpected errors.
  console.warn(e);
});
