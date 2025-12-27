# frozen_string_literal: true

require 'sinatra'
require 'erb'

require 'awesome_print'

require_relative 'parser'

get '/' do
  parser = Parser.new('./capture.txt')
  parser.process
  pqcli_data = parser.data

  charsheet = pqcli_data[:character]
  equipment = pqcli_data[:equipment]
  plot = pqcli_data[:plot]
  spellbook = pqcli_data[:spells]
  inventory = pqcli_data[:inventory]
  quests = pqcli_data[:quests]
  current_task = pqcli_data[:current_task]

  ap plot
  ap quests

  erb :home, locals: {
    charsheet: charsheet,
    equipment: equipment,
    plot: plot,
    spellbook: spellbook,
    inventory: inventory,
    quests: quests,
    current_task: current_task
  }
end
