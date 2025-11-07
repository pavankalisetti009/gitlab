# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Banzai::Filter::References::LabelReferenceFilter do
  include FilterSpecHelper

  let(:project) { create(:project, :public, name: 'sample-project') }
  let(:label) { create(:label, name: 'label', project: project) }
  let(:scoped_description) { 'xss <script>alert("scriptAlert");</script> &<a>lt;svg id=&quot;svgId&quot;&gt;&lt;/svg&gt;' }
  let(:scoped_label) { create(:label, name: 'key::value', project: project, description: scoped_description) }

  context 'with scoped labels enabled' do
    before do
      stub_licensed_features(scoped_labels: true)
    end

    context 'with a scoped label' do
      let(:doc) { reference_filter("See #{scoped_label.to_reference}") }

      it 'renders scoped label' do
        expect(doc.css('.gl-label-scoped').text).to eq(scoped_label.scoped_label_key + scoped_label.scoped_label_value)
      end

      it 'renders HTML tooltips' do
        expect(doc.at_css('.gl-label-scoped a').attr('data-html')).to eq('true')
      end

      it "doesn't unescape HTML in the label's title" do
        # Note that this is *flawed*: "&gt;" from the input *text* is becoming "&gt;" in the output *HTML*.
        # No XSS is possible but we are still corrupting the user's input, albeit less badly than before.
        # FIXME.
        expect(doc.at_css('.gl-label-scoped a').attr('title')).to include('&amp;lt;svg id="svgId"&gt;')

        # The below is what *should* be the case, but LabelsHelper.label_tooltip_title is (incorrectly) sanitising
        # instead of safely escaping the output, and LabelsHelper.render_label_text is using html_escape_once (!!),
        # which is always bad!
        #
        # expect(doc.at_css('.gl-label-scoped a').attr('title')).to include('xss &lt;script&gt;alert')
        # expect(doc.at_css('.gl-label-scoped a').attr('title')).to include('&amp;&lt;a&gt;lt;svg id=&amp;quot;svgId&amp;quot;&amp;gt;')
      end
    end

    context 'with a common label' do
      let(:doc) { reference_filter("See #{label.to_reference}") }

      it 'renders common label' do
        expect(doc.css('.gl-label .gl-label-text').map(&:text)).to eq([label.name])
      end

      it 'renders non-HTML tooltips' do
        expect(doc.at_css('.gl-label a').attr('data-html')).to be_nil
      end
    end
  end

  context 'with scoped labels disabled' do
    before do
      stub_licensed_features(scoped_labels: false)
    end

    it 'renders scoped label as a common label' do
      doc = reference_filter("See #{scoped_label.to_reference}")

      expect(doc.css('.gl-label .gl-label-text').map(&:text)).to eq([scoped_label.name])
    end
  end
end
