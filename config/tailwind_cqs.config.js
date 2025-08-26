/**
 * This is a temporary config file which we leverage to build a second Tailwind CSS bundle where
 * `@`-prefixed responsive utils are compiled to container queries rather than media queries.
 * When the CQs migration is complete and the `tailwind_container_queries` feature flag is removed,
 * we should remove this config and the code that uses it as building CQs will become the default.
 */

const tailwindCQsMQsPlugin = require('@gitlab/ui/tailwind_cqs_mqs_plugin');
const config = require('./tailwind.config');

/**
 * We have to assume that the tailwindCQsMQsPlugin is the last registered plugin in the default
 * config.
 */
config.plugins.splice(-1, tailwindCQsMQsPlugin(true));

module.exports = config;
