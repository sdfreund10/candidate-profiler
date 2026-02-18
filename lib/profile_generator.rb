require "dotenv/load"
require "ruby_llm"
require "ruby_llm/schema"
require "json"
require_relative "webpage"

RubyLLM.configure do |config|
  config.gemini_api_key = ENV["GEMINI_API_KEY"]
  config.default_model = "gemini-2.5-flash"
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
end

class ProfileGenerator
  attr_reader :text_profile, :json_profile, :status_updates
  def initialize(campaign_url, output_format: "markdown")
    @campaign_url = campaign_url
    @output_format = output_format
    @chat = RubyLLM::Chat.new.
      with_instructions(system_prompt).
      with_tool(FollowLink)
    @text_profile = nil
    @json_profile = nil
  end

  def incomplete?
    !@json_profile || !@text_profile
  end

  def complete?
    !incomplete?
  end

  def generate!(&block)
    starting_page = Webpage.new(@campaign_url).to_markdown
    chat = RubyLLM::Chat.new.
      with_instructions(system_prompt).
      with_tool(FollowLink)
    response = chat.ask(starting_page) do |stream|
      next unless block_given? && stream.content
      handle_stream_chunk(stream.content)
      block.call(@status_updates)
    end
    @text_profile = response.content

    @json_profile = RubyLLM::Chat.new.
      with_instructions(json_prompt).
      with_schema(CandidateProfile).
      ask(@text_profile).content

    self
  end

  Profile = Data.define(:candidate_name, :candidate_party, :candidate_background, :office_sought, :key_policy_issues, :key_endorsements)
  Issue = Data.define(:issue, :summary)
  def profile
    generate! unless @json_profile
    Profile.new(
      candidate_name: @json_profile["candidate_name"],
      candidate_party: @json_profile["candidate_party"],
      candidate_background: @json_profile["candidate_background"],
      office_sought: @json_profile["office_sought"],
      key_policy_issues: @json_profile["key_policy_issues"].map { |issue| Issue.new(issue["issue"], issue["summary"]) },
      key_endorsements: @json_profile["key_endorsements"]
    )
  end

  private

  def handle_stream_chunk(chunk)
    @status_buffer ||= ""
    @status_updates ||= []

    return unless chunk
    @status_buffer << chunk
    # puts "Status buffer: #{@status_buffer}"
    # TODO: Not reliably ending in new lines
    if @status_buffer.include?("\n")
      *lines, @status_buffer = @status_buffer.split("\n")
      @status_updates.concat(lines)
    elsif @status_buffer.include?(".")
      *lines, @status_buffer = @status_buffer.split(".")
      @status_updates.concat(lines)
    end
  end

  def system_prompt
    <<~PROMPT
      You are a helpful assistant preparing a profile of a political candidate for a voter.
      Your taks is to collext the essential information a voter needs to know about the candidate from their campaign website.

      You will initially be given a markdown version of the candidate's campaign website home page.
      Collect what information you can from the page, then follow links to other pages and collect information there.

      Look for the following information:
      - Candidate background
        - Keep the candidate's background brief, no more than 1 paragraph or 125 words.
        - Include where they are from, what they did before running for office, and why they want to run for office.
      - Key policy issues
        - Include top 5 issues and a brief summary of the candidate's positions and promises on each.
      - Key endorsements
        - Only include a few of the most important endorsements.

      Once you have collected all the information, output the profile in markdown format.

      Try to utilize the campaign's words as much as possible.
      If information is not available, explicitly state that it is not present.
      Keep the tone informative and neutral.
      The output should be concise enough to fit on a single flyer.
      Your result should be in #{@output_format} format.
      Provide passive-voice status updates on your progress as you follow links and collect information, alawys ending with a new line.
      Your final response should container only the candidate profile.
    PROMPT
  end

  def json_prompt
    <<~PROMPT
      You are an election official tasked with creating profiles of candidates for political office.
      You will be given a markdown version of a candidates profile prepared by an assistant.
      You task is to convert the markdown into JSON format without losing any information.
      Return only the JSON content, with not other text or formatting.
    PROMPT
  end
  class CandidateProfile <  RubyLLM::Schema
    string :candidate_name
    string :candidate_party
    string :candidate_background
    string :office_sought, description: "Specific details about the race. Include the office and the district."
    array :key_policy_issues do
      object do
        string :issue
        string :summary
      end
    end
    array :key_endorsements do
      string :endorsement
    end
  end

  class FollowLink < RubyLLM::Tool
    description "Follows a link to a campaign website page and returns the markdown version of the page."

    params do
      string :url, description: "The URL of the campaign website page to follow."
    end

    def execute(url:)
      puts "Following link: #{url}"
      Webpage.new(url).to_markdown
    rescue StandardError => e
      puts "Error following link #{url}: #{e.message}"
      "Could not open and parse the link"
    end
  end
end
