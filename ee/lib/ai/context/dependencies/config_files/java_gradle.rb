# frozen_string_literal: true

module Ai
  module Context
    module Dependencies
      module ConfigFiles
        class JavaGradle < Base
          START_SECTION_REGEX = /^dependencies {/ # Identifies the dependencies section
          END_SECTION_REGEX = /^}$/
          PREFIX_REGEX = /^(implementation |testImplementation )/ # Appears before each dependency
          LONG_FORM_KEYWORD = 'name:' # Only present in the long form dependency definition
          LONG_FORM_NAME_REGEX = /name:\s*(?<value>[^,\s]*)/
          LONG_FORM_VERSION_REGEX = /version:\s*(?<value>[^,\s]*)/
          EXCLUDE_KEYWORD = '('

          def self.file_name_glob
            'build.gradle'
          end

          def self.lang_name
            'Java'
          end

          private

          ### Example format:
          #
          # dependencies {
          #     // Short form: <group>:<name>:<version>
          #     implementation 'org.codehaus.groovy:groovy:3.+'
          #     testImplementation "com.google.guava:guava:29.0.1"
          #     "implementation" 'org.ow2.asm:asm:9.6'
          #
          #     // Long form
          #     implementation group: "org.neo4j", name: "neo4j-jmx", version: "1.3"
          #     testImplementation group: 'junit', name: 'junit', version: '4.11'
          #     "testImplementation" group: "org.apache.ant", name: "ant", version: "1.10.14"
          #
          #     // Project, file, or other dependencies are ignored
          #     implementation project(':utils')
          #     runtimeOnly files('libs/a.jar', 'libs/b.jar')
          #
          #     // TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/481317
          #     // String interpolation is not currently supported; below outputs "$arcgisVersion" as version
          #     implementation "com.esri.arcgisruntime:arcgis-java:$arcgisVersion"
          # }
          #
          def extract_libs
            libs = []
            in_deps_section = false

            content.each_line do |line|
              line.strip!
              line.gsub!(/'|"/, '')

              if START_SECTION_REGEX.match?(line)
                in_deps_section = true
              elsif in_deps_section && PREFIX_REGEX.match?(line)
                libs << parse_lib(line) unless line.include?(EXCLUDE_KEYWORD)
              elsif in_deps_section && END_SECTION_REGEX.match?(line)
                break
              end
            end

            libs
          end

          def parse_lib(line)
            line.gsub!(PREFIX_REGEX, '')

            if line.include?(LONG_FORM_KEYWORD)
              # Parse long form
              name = LONG_FORM_NAME_REGEX.match(line).try(:[], 'value')
              version = LONG_FORM_VERSION_REGEX.match(line).try(:[], 'value')
            else
              # Parse short form
              _group, name, version = line.split(':')
            end

            Lib.new(name: name, version: version)
          end
        end
      end
    end
  end
end
