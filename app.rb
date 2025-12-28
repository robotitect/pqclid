# frozen_string_literal: true

require 'sinatra'
require 'erb'

require 'awesome_print'

require_relative 'parser'

get '/' do

  running = system('tmux', 'capture-pane', '-t', 'pqcli', '-pJ', out: '.capture')
  filename = '.capture'

  if running
    puts "Capture: SUCCESS! pqcli running, capture saved to .capture and .capture.old"
    _ = system('cp', '.capture', '.capture.old')
  else
    print "Capture FAILED. "
    puts "pqcli most likely not running, using previous .capture.old"
    filename = '.capture.old'
  end

  current_time = File.mtime(filename).strftime('%r [%F]')

  parser = Parser.new(filename)
  parser.process
  pqcli_data = parser.data

  charsheet = pqcli_data[:character]
  equipment = pqcli_data[:equipment]
  plot = pqcli_data[:plot]
  spellbook = pqcli_data[:spells]
  inventory = pqcli_data[:inventory]
  quests = pqcli_data[:quests]
  current_task = pqcli_data[:current_task]

  erb :home, locals: {
    charsheet: pqcli_data[:character],
    equipment: pqcli_data[:equipment],
    plot: pqcli_data[:plot],
    spellbook: pqcli_data[:spells],
    inventory: pqcli_data[:inventory],
    quests: pqcli_data[:quests],
    current_task: pqcli_data[:current_task],
    current_time: current_time,
    running: running,
  }
end
