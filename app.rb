# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("lib", __dir__))
require "dotenv/load"
require "sinatra/base"
require "profile_generator"
require "kramdown"
require "debug"

class CandidateSummaryApp < Sinatra::Base
  set :root, File.expand_path(__dir__)
  set :views, (proc { File.join(root, "views") })
  set :public_folder, File.expand_path("public", __dir__)

  get "/" do
    erb :index
  end

  get "/profile" do
    campaign_url = params[:campaign_url].to_s.strip
    if campaign_url.empty?
      @error = "Please enter a campaign URL."
      @campaign_url = ""
      return erb :index
    end
    erb :profile, locals: { campaign_url: campaign_url }
  end

  # TODO: There must be some way to stream intermediate status updates to the loading page
  GENERATOR_CACHE = {}
  get "/candidate-profile" do
    campaign_url = params[:campaign_url].to_s.strip
    return if campaign_url.empty?

    @generator = GENERATOR_CACHE[campaign_url]

    if @generator.nil?
      @generator = ProfileGenerator.new(campaign_url)
      GENERATOR_CACHE[campaign_url] = @generator
    end

    # stream updates -- will this even work?
    if @generator.incomplete?
      @generator.generate!
    end

    if @generator.complete?
      @profile = @generator.profile
      @text_profile = @generator.text_profile
      @campaign_url = campaign_url
    end

    content_type 'text/html'
    erb :candidate_profile
  end

  post "/profile" do
    campaign_url = params[:campaign_url].to_s.strip
    if campaign_url.empty?
      @error = "Please enter a campaign URL."
      @campaign_url = ""
      return erb :index
    end

    redirect "/profile?campaign_url=#{URI.encode_www_form_component(campaign_url)}"
  end

  def escape_sse(str)
    str.to_s.gsub(/\n/, " ").gsub(/\r/, "")
  end

  # start the server if ruby file executed directly
  run! if app_file == $0
end
