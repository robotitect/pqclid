# frozen_string_literal: true

require 'sinatra'
require 'erb'

require 'awesome_print'

require_relative 'parser'

get '/' do
  parser = Parser.new('./capture.txt')
  parser.process
  pqcli_data = parser.data

  ap pqcli_data

  ERB.new(
    'Hello World!'
  ).result(binding)
end
