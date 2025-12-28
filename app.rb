# frozen_string_literal: true

require 'sinatra'
require 'erb'

require 'awesome_print'

require_relative 'parser'

get '/' do
  current_time = Time.now.strftime('%r [%F]')

  if system('tmux', 'capture-pane', '-t', 'pqcli', '-pJ', out: '.capture')
    puts "Capture: SUCCESS! Saved to .capture"
  else
    puts "Capture FAILED. Using previous .capture"
  end

  parser = Parser.new('.capture')
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
    current_time: current_time
  }
end
