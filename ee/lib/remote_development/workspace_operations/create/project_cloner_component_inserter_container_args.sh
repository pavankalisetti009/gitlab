echo "$(date -Iseconds): ----------------------------------------"
echo "$(date -Iseconds): Cloning project if necessary..."

if [ -f "%<project_cloning_successful_file>s" ]
then
  echo "$(date -Iseconds): Project cloning was already successful"
  exit 0
fi

if [ -d "%<clone_dir>s" ]
then
  echo "$(date -Iseconds): Removing unsuccessfully cloned project directory"
  rm -rf "%<clone_dir>s"
fi

echo "$(date -Iseconds): Cloning project"
git clone --branch "%<project_ref>s" "%<project_url>s" "%<clone_dir>s"
exit_code=$?

if [ "${exit_code}" -eq 0 ]
then
  echo "$(date -Iseconds): Project cloning successful"
  touch "%<project_cloning_successful_file>s"
  echo "$(date -Iseconds): Updated file to indicate successful project cloning"
else
  echo "$(date -Iseconds): Project cloning failed with exit code: ${exit_code}" >&2
fi

echo "$(date -Iseconds): Finished cloning project if necessary."
exit "${exit_code}"
