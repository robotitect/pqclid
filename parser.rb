# frozen_string_literal: true

require 'awesome_print'
require 'roman-numerals'

require_relative 'pq_cli_parse'

# Parser for PQCLI "screenshots"
class Parser
  include PqCliParse

  attr_reader :data

  def process
    data = process_capture

    # Parse last 2 lines of screen i.e. current task and percentage
    current_task_lines = @capture[-2..]

    data[:current_task] = CurrentTask.new(
      text: current_task_lines.first.strip,
      percent_completed: parse_percent_time_left(current_task_lines.last).first
    )

    @data = data
  end

  private

  def initialize(file)
    @capture = File.readlines(file)
  end

  # Parses all the data in the read in file (@capture)
  # "capture" refers to the tmux capture
  def process_capture
    data = PqData.new

    # 1. top_left_corners here is a method call that goes through @capture to
    #    extract all the top left corners of each of the 6 boxes
    # 2. textboxes() takes each top left corner coordinates (row, column) and
    #    uses them to obtain the actual text for each of the boxes
    # 3. This block operates on each of those textboxes
    textboxes(top_left_corners).each do |textbox|
      textbox_data, symbol = parse_textbox_data_and_symbol(textbox)
      data[symbol] = textbox_data
    end

    data
  end

  def top_left_corners
    top_left_corners = []

    @capture.each_with_index do |line, row|
      top_left_corners += top_left_corners_from_line(line, row)
    end

    top_left_corners
  end
end
