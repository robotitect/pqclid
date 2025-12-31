# frozen_string_literal: true

require 'bundler/setup'

require 'sinatra'
require 'erb'

require_relative 'parser'
require_relative 'pq_cli_sys'

set :port, 11662

get '/' do
  filename, capture_success = PqCliSys.capture_and_write_to_file
  capture_time = File.mtime(filename).strftime('%r [%F]')

  parser = Parser.new(filename)
  parser.process
  pqcli_data = parser.data

  erb :home, locals: {
    charsheet: pqcli_data[:charsheet],
    equipment: pqcli_data[:equipment],
    plot: pqcli_data[:plot],
    spellbook: pqcli_data[:spells],
    inventory: pqcli_data[:inventory],
    quests: pqcli_data[:quests],
    current_task: pqcli_data[:current_task],
    capture_time: capture_time,
    running: capture_success
  }
end
