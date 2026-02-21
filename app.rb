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

  GENERATOR_CACHE = {}
  get "/candidate-profile" do
    campaign_url = params[:campaign_url].to_s.strip
    return if campaign_url.empty?

    @generator = GENERATOR_CACHE[campaign_url]

    if @generator.nil?
      @generator = ProfileGenerator.new(campaign_url)
      GENERATOR_CACHE[campaign_url] = @generator
    end

    if @generator.complete?
      @profile = @generator.profile
      @text_profile = @generator.text_profile
      @campaign_url = campaign_url
      final_html = erb(:candidate_profile, layout: false)
      replace_stream = wrap_turbo_stream_replace("profile", final_html)
      content_type 'text/event-stream'
      cache_control :no_cache
      headers 'X-Accel-Buffering' => 'no'
      body sse_data(replace_stream)
    else
      content_type 'text/event-stream'
      cache_control :no_cache
      headers 'X-Accel-Buffering' => 'no' # Disables buffering in Nginx if you use it

      stream(:keep_open) do |out|
        begin
          @generator.generate! do |_status_update|
            status_html = erb(:_statuses, locals: { status_updates: @generator.status_updates }, layout: false)
            out << sse_data(status_html)
          end
          @profile = @generator.profile
          @text_profile = @generator.text_profile
          @campaign_url = campaign_url
          final_html = erb(:candidate_profile, locals: { profile: @profile, text_profile: @text_profile, campaign_url: @campaign_url }, layout: false)
          out << sse_data(wrap_turbo_stream_replace("profile", final_html))
        ensure
          out.close
        end
      end
    end
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

  # Format a string as one SSE event body (multi-line data).
  def sse_data(str)
    str.to_s.split("\n").map { |line| "data: #{line}\n" }.join + "\n"
  end

  # Wrap HTML in a turbo-stream replace so <turbo-stream-source> can apply it without custom JS.
  def wrap_turbo_stream_replace(target_id, html)
    "<turbo-stream action=\"replace\" target=\"#{target_id}\"><template>#{html}</template></turbo-stream>"
  end

  # start the server if ruby file executed directly
  run! if app_file == $0
end
