require 'logger'
require_relative "app"

puts "Starting with ENV: #{ENV.inspect}"

use Rack::CommonLogger, Logger.new(STDOUT)
run CandidateSummaryApp
