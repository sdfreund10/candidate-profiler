# frozen_string_literal: true

require "stringio"
require "spec_helper"

RSpec.describe Webpage do
  let(:sample_html) do
    <<~HTML
      <!DOCTYPE html>
      <html>
        <head><title>Example Page</title></head>
        <body>
          <h1>Hello</h1>
          <p>First paragraph.</p>
          <p>Second   paragraph.</p>
        </body>
      </html>
    HTML
  end

  def stub_fetch(html = sample_html)
    response = StringIO.new(html)
    allow(URI).to receive(:open).and_return(response)
    yield
  end

  describe "#fetch" do
    it "returns self" do
      stub_fetch do
        page = described_class.new("https://example.com")
        expect(page.fetch).to be page
      end
    end
  end

  describe "#body" do
    it "returns raw HTML" do
      stub_fetch do
        page = described_class.new("https://example.com")
        expect(page.body).to eq(sample_html)
      end
    end

    it "caches after first call" do
      stub_fetch do
        page = described_class.new("https://example.com")
        expect(page.body).to eq(page.body)
      end
    end

    it "fetches automatically when not yet fetched" do
      stub_fetch do
        page = described_class.new("https://example.com")
        expect(page.body).to eq(sample_html)
      end
    end
  end

  describe "#doc" do
    it "returns a Nokogiri document" do
      stub_fetch do
        page = described_class.new("https://example.com")
        expect(page.doc).to be_a(Nokogiri::HTML4::Document)
      end
    end

    it "parses the body" do
      stub_fetch do
        page = described_class.new("https://example.com")
        expect(page.doc.at_css("h1").text).to eq("Hello")
        expect(page.doc.css("p").size).to eq(2)
      end
    end
  end

  describe "#title" do
    it "returns the page title" do
      stub_fetch do
        page = described_class.new("https://example.com")
        expect(page.title).to eq("Example Page")
      end
    end

    it "returns nil when there is no title element" do
      html = "<html><body><p>No title</p></body></html>"
      stub_fetch(html) do
        page = described_class.new("https://example.com")
        expect(page.title).to be_nil
      end
    end
  end

  describe "#text" do
    it "returns body text with normalized whitespace" do
      stub_fetch do
        page = described_class.new("https://example.com")
        text = page.text
        expect(text).to include("Hello")
        expect(text).to include("First paragraph")
        expect(text).to include("Second paragraph")
        expect(text).not_to match(/\s{2,}/)
      end
    end

    it "returns empty string when there is no body" do
      html = "<html><head><title>No body</title></head></html>"
      stub_fetch(html) do
        page = described_class.new("https://example.com")
        expect(page.text).to eq("")
      end
    end
  end

  describe "#to_markdown" do
    it "converts body HTML to markdown" do
      stub_fetch do
        page = described_class.new("https://example.com")
        md = page.to_markdown
        expect(md).to include("# Example Page")
        expect(md).to include("Hello")
        expect(md).to include("First paragraph")
        expect(md).to include("Second paragraph")
      end
    end

    it "prepends title as top-level heading when present" do
      stub_fetch do
        page = described_class.new("https://example.com")
        expect(page.to_markdown).to start_with("# Example Page\n\n")
      end
    end

    it "returns markdown without title heading when title is missing" do
      html = "<html><body><p>Content only</p></body></html>"
      stub_fetch(html) do
        page = described_class.new("https://example.com")
        expect(page.to_markdown).not_to start_with("# ")
        expect(page.to_markdown).to include("Content only")
      end
    end
  end
end
