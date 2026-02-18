# frozen_string_literal: true

require "open-uri"
require "nokogiri"
require "reverse_markdown"

class Webpage
  def initialize(url)
    @url = url
  end

  def fetch
    @response = URI.open(@url, read_timeout: 10)
    self
  end

  def body
    fetch unless @response
    @body ||= @response.read
  end

  def doc
    @doc ||= Nokogiri::HTML(body)
  end

  def title
    doc.at_css("title")&.text&.strip
  end

  def text
    doc.at_css("body")&.text&.strip&.gsub(/\s+/, " ") || ""
  end

  def to_markdown
    body_node = doc.at_css("body") || doc
    md = ReverseMarkdown.convert(body_node, unknown_tags: :bypass)
    md = md.strip.gsub(/\n{3,}/, "\n\n")
    if (t = title).to_s != ""
      "# #{t}\n\n#{md}"
    else
      md
    end
  end
end
