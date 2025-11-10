# frozen_string_literal: true

require 'yaml'

# Checks the alphabetical ordering of table names
# in config/gitlab_loose_foreign_keys.yml
class LooseForeignKeysOrderingChecker
  LOOSE_FOREIGN_KEYS_PATH = 'config/gitlab_loose_foreign_keys.yml'
  ERROR_CODE = 1

  Result = Struct.new(:error_code, :error_message)

  def check
    unless File.exist?(LOOSE_FOREIGN_KEYS_PATH)
      return Result.new(ERROR_CODE, "\e[31mError: #{LOOSE_FOREIGN_KEYS_PATH} not found\e[0m")
    end

    yaml_content = File.read(LOOSE_FOREIGN_KEYS_PATH)
    parsed = YAML.safe_load(yaml_content)

    return if parsed.nil? || parsed.empty?

    table_names = parsed.keys
    sorted_table_names = table_names.sort

    return if table_names == sorted_table_names

    format_error_result(table_names, sorted_table_names)
  end

  private

  def format_error_result(table_names, sorted_table_names)
    misordered_tables = find_misordered_tables(table_names, sorted_table_names)

    message = "\e[31mError: Table names in #{LOOSE_FOREIGN_KEYS_PATH} are not in alphabetical order\n\n"
    message += "The following tables are out of order:\n\n"

    misordered_tables.each do |table, expected_position|
      message += "  • #{table}\n"
      message += "    Expected position: #{expected_position}\n\n"
    end

    message += "Please reorder the tables alphabetically.\n\e[0m"

    Result.new(ERROR_CODE, message)
  end

  def find_misordered_tables(table_names, sorted_table_names)
    misordered = {}

    table_names.each_with_index do |table, index|
      expected_index = sorted_table_names.index(table)
      next if index == expected_index

      misordered[table] = if expected_index == 0
                            "First (before #{sorted_table_names[1]})"
                          elsif expected_index == sorted_table_names.length - 1
                            "Last (after #{sorted_table_names[expected_index - 1]})"
                          else
                            "Between #{sorted_table_names[expected_index - 1]} and " \
                              "#{sorted_table_names[expected_index + 1]}"
                          end
    end

    misordered
  end
end
