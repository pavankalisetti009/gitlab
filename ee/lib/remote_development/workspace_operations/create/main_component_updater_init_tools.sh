#!/bin/sh
echo "$(date -Iseconds): ----------------------------------------"
echo "$(date -Iseconds): Running ${GL_TOOLS_DIR}/init_tools.sh with output written to ${GL_WORKSPACE_LOGS_DIR}/init-tools.log..."
"${GL_TOOLS_DIR}/init_tools.sh" >> "${GL_WORKSPACE_LOGS_DIR}/init-tools.log" 2>&1 &
echo "$(date -Iseconds): Finished running ${GL_TOOLS_DIR}/init_tools.sh."
