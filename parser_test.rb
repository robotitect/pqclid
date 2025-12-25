# frozen_string_literal: true

require 'awesome_print'

require_relative 'parser'

parser = Parser.new('./capture.txt')
parser.process
pqcli_data = parser.data

ap pqcli_data
