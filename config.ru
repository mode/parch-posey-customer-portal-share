require 'bundler'
Bundler.require
Dotenv.load

require './app'

run Sinatra::Application
