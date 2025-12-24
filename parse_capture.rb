# frozen_string_literal: true

require 'awesome_print'
require 'roman-numerals'

HEADER_CHAR_SHEET = 'Character Sheet'
HEADER_EQUIPMENT = 'Equipment'
HEADER_PLOT_DEV = 'Plot Development'
HEADER_SPELL_BOOK = 'Spell Book'
HEADER_INVENTORY = 'Inventory'
HEADER_QUESTS = 'Quests'

CHAR_SHEET_INT_ATTRS = ['Level', 'STR', 'CON', 'DEX', 'INT', 'WIS', 'CHA',
                        'HP Max', 'MP Max', 'XP', 'XP Needed',
                        'XP Remaining'].freeze
CHAR_SHEET_RATIONAL_ATTRS = ['XP (%)', 'Time Left (h)'].freeze

TITLE_MATCHER = /([ \w]+)/
TOP_LEFT_CORNER_MATCHER = /(?=┌)/
NUM_MATCHER = /(\d*\.?\d+)/
TIME_MATCHER = /(\d*\.?\d+).*([a-zA-Z]+)/
XP_REMAINING_MATCHER = /(\d+)/
INV_SPACES_MATCHER = %r{(\d+)?/(\d+)}

# Coordinates of a specific character, used for the top left corners of each
# textbox, which are indicated with '┌'.
Coordinates = Struct.new(:row, :col)

# A line in Plot Development or Quests; has a completion marker before it,
# showing either: [ ] for incomplete, or [X] for complete.
Task = Struct.new(:text, :completed)

# Information from the last 2 lines in the screen, i.e. the current task being
# completed and the completion percentage.
CurrentTask = Struct.new(:text, :percent_completed)

# Contains all the parsed data from the 7 screen regions (6 textboxes + current
# task at the bottom).
PqData = Struct.new(:character, :equipment, :plot, :spells, :inventory, :quests,
                    :current_task)

capture = File.readlines(ARGV[0])

top_left_corners = []

capture.each_with_index do |line, row|
  indices_top_left = line.enum_for(:scan, TOP_LEFT_CORNER_MATCHER).map do
    Regexp.last_match.offset(0).first
  end

  indices_top_left.each do |col|
    top_left_corners << Coordinates.new(row: row, col: col)
  end
end

# Get text for all boxes
textboxes = []

top_left_corners.each do |coords|
  first_row = coords.row
  first_col = coords.col

  # Go right until get top right corner
  last_col =
    first_col + capture[first_row].chars.drop(first_col).find_index('┐')

  # Go down until get bot left corner
  last_row = first_row
  (first_row...capture.size).each do |row|
    char = capture[row].chars[first_col]
    if char == '└'
      last_row = row
      break
    end
  end

  # Extract each line based on corners
  textboxes << (first_row..last_row).map do |r|
    capture[r][first_col..last_col]
  end
end

def validate_textbox_header?(textbox, header)
  textbox.first[TITLE_MATCHER].strip == header
end

def filter_textbox(textbox)
  # 1st [1..-2]: Skip first and last lines (both are just '----------------')
  # 2nd [1..-2]: Skip first and last columns (both are just '|')
  # 1st map (split): Split along long lengths of spaces
  # 2nd map (strip/reject): Remove empty strings
  textbox[1..-2].map do |line|
    line[1..-2].split('  ').map(&:strip).reject { it == '' }
  end.compact # Remove nils
end

def parse_generic(textbox)
  filter_textbox(textbox).select { it.size == 2 }.to_h
end

def parse_percent_time_left(line)
  split_line = line.strip.split

  percent = split_line.first[NUM_MATCHER].to_r

  time_left, time_unit =
    if split_line.size == 2
      TIME_MATCHER.match(split_line.last).captures
    else
      [0, 'm']
    end

  [percent, time_left.to_r, time_unit]
end

def parse_experience_textbox(textbox)
  tb_xp = filter_textbox(textbox).select { it.size == 1 }.flatten
  xp_remaining = tb_xp.first[XP_REMAINING_MATCHER].to_i

  xp_percent, xp_time_left, xp_time_unit = parse_percent_time_left(tb_xp.last)
  [xp_remaining, xp_percent, xp_time_left, xp_time_unit]
end

def calc_xp(xp_remaining, xp_percent)
  xp_total_to_next_lvl =
    (xp_remaining / ((100r - xp_percent)/100r)).round.to_i
  xp_current = xp_total_to_next_lvl - xp_remaining.round.to_i
  [xp_current, xp_total_to_next_lvl]
end

def parse_experience(textbox)
  xp_remaining, xp_pct, time_left, time_unit = parse_experience_textbox(textbox)
  xp_current, xp_total_to_next_lvl = calc_xp(xp_remaining, xp_pct)

  {
    'XP' => xp_current,
    'XP Needed' => xp_total_to_next_lvl,
    'XP Remaining' => xp_remaining,
    'XP (%)' => xp_pct,
    'Time Left (h)' => time_left,
    'Time Unit' => time_unit
  }
end

def filter_todo_list(textbox)
  filter_textbox(textbox).select { it.size == 1 }
                         .flatten
                         .reject { it.include?('───────') }
end

# For to-do list style boxes (Plot Development, Quests)
def parse_todo_list(textbox)
  filtered_tb = filter_todo_list(textbox)

  # For all lines but the last, get the tasks and the progress ([x] or [ ])
  tasks = filtered_tb[...-1].map do |line|
    Task.new(
      text: line[1] == 'X',
      completed: line[3..].strip
    )
  end

  percent_completed, time_left, time_unit =
    parse_percent_time_left(filtered_tb.last)

  [tasks, percent_completed, time_left, time_unit]
end

def convert_character_sheet(charsheet_data)
  charsheet_data.each do |key, val|
    if CHAR_SHEET_INT_ATTRS.include?(key)
      charsheet_data[key] = val.to_i
    elsif CHAR_SHEET_RATIONAL_ATTRS.include?(key)
      charsheet_data[key] = val.to_r
    end
  end
end

def parse_character_sheet(textbox)
  return unless validate_textbox_header?(textbox, HEADER_CHAR_SHEET)

  char_data = parse_generic(textbox).merge(parse_experience(textbox))

  convert_character_sheet(char_data)
end

def parse_equipment(textbox)
  return unless validate_textbox_header?(textbox, HEADER_EQUIPMENT)

  parse_generic(textbox)
end

def parse_plot_development(textbox)
  return unless validate_textbox_header?(textbox, HEADER_PLOT_DEV)

  acts, percent_completed, time_left, time_unit = parse_todo_list(textbox)

  {
    'Acts' => acts,
    'Completed %' => percent_completed,
    'Time Left' => time_left,
    'Time Unit' => time_unit
  }
end

def parse_spell_book(textbox)
  return unless validate_textbox_header?(textbox, HEADER_SPELL_BOOK)

  parse_generic(textbox).transform_values { RomanNumerals.to_decimal(it) }
end

def filter_inventory(textbox)
  filter_textbox(textbox).select { it.size == 1 }.flatten
end

def parse_inventory(textbox)
  return unless validate_textbox_header?(textbox, HEADER_INVENTORY)

  filtered_tb = filter_inventory(textbox)

  inv_data = {
    'Items' => parse_generic(textbox).transform_values(&:to_i),
    'Encumbrance (%)' => parse_percent_time_left(filtered_tb.last).first
  }

  inv_data['Inventory Spaces Filled'],
    inv_data['Inventory Spaces Max'] =
    INV_SPACES_MATCHER.match(filtered_tb.first).captures.map(&:to_i)

  inv_data
end

def parse_quests(textbox)
  return unless validate_textbox_header?(textbox, HEADER_QUESTS)

  quests, percent_completed, time_left, time_unit = parse_todo_list(textbox)

  {
    'Quests' => quests,
    'Completed %' => percent_completed,
    'Time Left' => time_left,
    'Time Unit' => time_unit
  }
end

data = PqData.new

textboxes.each do |textbox|
  title = textbox.first[TITLE_MATCHER].strip

  textbox_data, symbol =
    case title
    when HEADER_CHAR_SHEET
      [parse_character_sheet(textbox), :character]
    when HEADER_EQUIPMENT
      [parse_equipment(textbox), :equipment]
    when HEADER_PLOT_DEV
      [parse_plot_development(textbox), :plot]
    when HEADER_SPELL_BOOK
      [parse_spell_book(textbox), :spells]
    when HEADER_INVENTORY
      [parse_inventory(textbox), :inventory]
    when HEADER_QUESTS
      [parse_quests(textbox), :quests]
    end

  data[symbol] = textbox_data
end

# Parse last 2 lines of screen i.e. current task and percentage
current_task_lines = capture[-2..]

data[:current_task] = CurrentTask.new(
  text: current_task_lines.first.strip,
  percent_completed: parse_percent_time_left(current_task_lines.last).first
)

ap data
