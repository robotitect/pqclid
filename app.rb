require 'sinatra'
require 'erb'

require 'awesome_print'

require './parser'

get '/' do

  parser = Parser.new('./capture.txt')
  pqcli_data = parser.process

  ap pqcli_data

  ERB.new(
    'Hello World!'
  ).result(binding)
end
