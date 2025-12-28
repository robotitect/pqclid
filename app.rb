# frozen_string_literal: true

require 'sinatra'
require 'erb'

require_relative 'parser'

get '/' do
  # Set window size to 150x10,000 for max information
  _ = system('tmux', 'resize-window', '-t', 'pqcli', '-x', '150', '-y', '10000')

  # Capture pane with the spoofed size
  running =
    system('tmux', 'capture-pane', '-t', 'pqcli', '-pJ', out: '.capture')

  # Reset the size so that `tmux a` to the session resizes to fit the terminal
  _ = system('tmux', 'set-option', '-t', 'pqcli', 'window-size', 'largest')

  filename = '.capture'

  if running
    print "Capture: SUCCESS! "
    puts "pqcli running, capture saved to .capture and .capture.old"
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
