# frozen_string_literal: true

module Ai
  module Context
    module Dependencies
      module ConfigFiles
        class KotlinGradle < Base
          PREFIX_REGEX = /^(implementation|testImplementation)\(/ # Appears before each dependency
          START_DEPS_SECTION_REGEX = /^dependencies {/ # Identifies the dependencies section
          END_SECTION_REGEX = /^}$/
          QUOTED_VALUE_REGEX = /(?<quote>["'])(?<value>[^"']+)\k<quote>/ # Matches value between double or single quotes
          INLINE_COMMENT_REGEX = %r{\s+//.*$}
          STRING_INTERPOLATION_CHAR = '$'
          EXCLUDE_KEYWORD = '('

          def self.file_name_glob
            'build.gradle.kts'
          end

          def self.lang_name
            'Kotlin'
          end

          private

          ### Example format:
          #
          # dependencies {
          #     // Format <group>:<name>:<version>
          #     implementation("org.codehaus.groovy:groovy:3.+")
          #     testImplementation("com.google.guava:guava:29.0.1") // Inline comment
          #
          #     // Project, file, or other dependencies are ignored
          #     implementation(project(":utils"))
          #     runtimeOnly(files("libs/a.jar", "libs/b.jar"))
          #
          #     // TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/481317
          #     // String interpolation is not currently supported; below outputs nil as version
          #     implementation("com.esri.arcgisruntime:arcgis-java:$arcgisVersion")
          # }
          #
          def extract_libs
            libs = []
            in_deps_section = false

            content.each_line do |line|
              line.strip!
              line.gsub!(INLINE_COMMENT_REGEX, '')

              if in_deps_section
                libs << parse_lib(line) if PREFIX_REGEX.match?(line)
                break if END_SECTION_REGEX.match?(line)
              elsif START_DEPS_SECTION_REGEX.match?(line)
                in_deps_section = true
              end
            end

            libs.compact
          end

          def parse_lib(line)
            line.gsub!(PREFIX_REGEX, '')
            return if line.include?(EXCLUDE_KEYWORD)

            match = QUOTED_VALUE_REGEX.match(line)
            _group, name, version = match[:value].split(':') if match

            name = nil if name&.include?(STRING_INTERPOLATION_CHAR)
            version = nil if version&.include?(STRING_INTERPOLATION_CHAR)

            Lib.new(name: name, version: version) if name
          end
        end
      end
    end
  end
end
