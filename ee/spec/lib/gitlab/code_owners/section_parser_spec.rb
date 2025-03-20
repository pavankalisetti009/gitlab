# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CodeOwners::SectionParser, feature_category: :source_code_management do
  using RSpec::Parameterized::TableSyntax

  subject(:parser) { described_class.new(line, sectional_data, line_number) }

  let(:line) { 'line' }
  let(:line_number) { 1 }
  let(:sectional_data) { {} }

  describe '#errors' do
    subject(:errors) { parser.errors }

    it { is_expected.to be_instance_of(Gitlab::CodeOwners::Errors) }
  end

  describe '#execute' do
    subject(:section) { parser.execute }

    context 'when line is not a section header' do
      let(:line) { 'foo' }

      it { is_expected.to be_nil }
    end

    context 'when line is a section header' do
      let(:missing_section_name) { Gitlab::CodeOwners::Error.new(:missing_section_name, line_number) }
      let(:invalid_approval_requirement) { Gitlab::CodeOwners::Error.new(:invalid_approval_requirement, line_number) }
      let(:invalid_section_owner_format) { Gitlab::CodeOwners::Error.new(:invalid_section_owner_format, line_number) }

      where(:line, :name, :optional, :approvals, :default_owners, :sectional_data, :errors) do
        '[]'                  | ''    | false | 0 | ''          | {}              | [ref(:missing_section_name)]
        '[Doc]'               | 'Doc' | false | 0 | ''          | {}              | []
        '[Doc]'               | 'doc' | false | 0 | ''          | { 'doc' => {} } | []
        '[Doc]'               | 'Doc' | false | 0 | ''          | { 'foo' => {} } | []
        '^[Doc]'              | 'Doc' | true  | 0 | ''          | {}              | []
        '[Doc][1]'            | 'Doc' | false | 1 | ''          | {}              | []
        '^[Doc][1]'           | 'Doc' | true  | 1 | ''          | {}              | [ref(:invalid_approval_requirement)]
        '^[Doc][1] @doc'      | 'Doc' | true  | 1 | '@doc'      | {}              | [ref(:invalid_approval_requirement)]
        '^[Doc][1] @doc @dev' | 'Doc' | true  | 1 | '@doc @dev' | {}              | [ref(:invalid_approval_requirement)]
        '^[Doc][1] @gl/doc-1' | 'Doc' | true  | 1 | '@gl/doc-1' | {}              | [ref(:invalid_approval_requirement)]
        '[Doc][1] @doc'       | 'Doc' | false | 1 | '@doc'      | {}              | []
        '[Doc] @doc'          | 'Doc' | false | 0 | '@doc'      | {}              | []
        '^[Doc] @doc'         | 'Doc' | true  | 0 | '@doc'      | {}              | []
        '[Doc] @doc @rrr.dev @dev' | 'Doc' | false | 0 | '@doc @rrr.dev @dev' | {} | []
        '^[Doc] @doc @rrr.dev @dev' | 'Doc' | true | 0 | '@doc @rrr.dev @dev' | {} | []
        '[Doc][2] @doc @rrr.dev @dev' | 'Doc' | false | 2 | '@doc @rrr.dev @dev' | {} | []
        '[Doc] malformed' | 'Doc' | false | 0 | 'malformed' | {} | [ref(:invalid_section_owner_format)]
      end

      with_them do
        it 'parses all section properties', :aggregate_failures do
          expect(section).to be_present
          expect(section.name).to eq(name)
          expect(section.optional).to eq(optional)
          expect(section.approvals).to eq(approvals)
          expect(section.default_owners).to eq(default_owners)

          if errors.any?
            expect(parser.valid?).to be_falsey
            expect(parser.errors).to match_array(errors)
          else
            expect(parser.valid?).to be_truthy
          end
        end
      end
    end

    context 'when section header is invalid' do
      let(:error) { Gitlab::CodeOwners::Error.new(:invalid_section_format, line_number) }

      where(:line, :status, :errors) do
        '^[Invalid' | false | [ref(:error)]
        '[Invalid'  | false | [ref(:error)]
      end

      with_them do
        it 'validates section correctness' do
          expect(section).to be_nil

          expect(parser.valid?).to eq(status)
          expect(parser.errors).to match_array(errors)
        end
      end
    end
  end
end
