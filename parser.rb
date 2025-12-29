# frozen_string_literal: true

require 'awesome_print'
require 'roman-numerals'

# Parser for PQCLI "screenshots"
class Parser
  CAPTURE_FILENAME_OUT_TEXT = {
    true =>
      ['.capture', 'Capture success! pqcli running, capture saved to .capture' +
       ' and .capture.old'],
    false =>
      ['.capture.old', 'Capture failed (pqcli may not be running). Using ' +
       'previous .capture.old']
  }.freeze

  HEADER = { charsheet: 'Character Sheet', equipment: 'Equipment',
             plot: 'Plot Development', spells: 'Spell Book',
             inventory: 'Inventory', quests: 'Quests' }.freeze

  CHAR_SHEET_INT_ATTRS = ['Level', 'STR', 'CON', 'DEX', 'INT', 'WIS', 'CHA',
                          'HP Max', 'MP Max', 'XP', 'XP Needed',
                          'XP Remaining'].freeze
  CHAR_SHEET_RATIONAL_ATTRS = ['XP (%)', 'Time Left (h)'].freeze

  # rubocop:disable Style/MutableConstant
  CHAR_SHEET_ATTR_TO_EMOJI = {
    'Name' => '❝',
    'Race' => '🏁',
    'Class' => '✍️',
    'Level' => '📈',
    'STR' => '💪',
    'CON' => '🩸',
    'DEX' => '🤌',
    'INT' => '🧠',
    'WIS' => '🧓',
    'CHA' => '😍',
    'HP Max' => '❤️',
    'MP Max' => '🪄'
  }
  CHAR_SHEET_ATTR_TO_EMOJI.default = ''
  CHAR_SHEET_ATTR_TO_EMOJI.freeze
  # rubocop:enable Style/MutableConstant

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

  # Contains all the parsed data from the 7 screen regions (6 textboxes +
  # current task at the bottom).
  PqData = Struct.new(:charsheet, :equipment, :plot, :spells, :inventory,
                      :quests, :current_task)

  attr_reader :data

  def self.capture_and_write_to_file_sys
    # Set window size to 150x10,000 for max information
    resized_for_capture =
      system('tmux', 'resize-window', '-t', 'pqcli', '-x', '150', '-y', '10000')

    # Capture pane with the spoofed size
    captured =
      system('tmux', 'capture-pane', '-t', 'pqcli', '-pJ', out: '.capture')

    # Reset the size so that `tmux a` to the session resizes to fit the terminal
    resized_back_to_auto =
      system('tmux', 'set-option', '-t', 'pqcli', 'window-size', 'largest')

    resized_for_capture and captured and resized_back_to_auto
  end

  def self.capture_and_write_to_file
    success = Parser.capture_and_write_to_file_sys
    system('cp', '.capture', '.capture.old') if success

    filename, out_text = CAPTURE_FILENAME_OUT_TEXT[success]
    puts out_text

    [filename, success]
  end

  def self.top_left_corners_from_line(line, row_number)
    indices_top_left = line.enum_for(:scan, TOP_LEFT_CORNER_MATCHER).map do
      Regexp.last_match.offset(0).first
    end

    indices_top_left.map do |col|
      Coordinates.new(row: row_number, col: col)
    end
  end

  def self.validate_textbox_header?(textbox, header)
    textbox.first[TITLE_MATCHER].strip == header
  end

  def self.parse_percent_time_left(line)
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

  def self.calc_xp(xp_remaining, xp_percent)
    xp_total_to_next_lvl =
      (xp_remaining / ((100r - xp_percent)/100r)).round.to_i
    xp_current = xp_total_to_next_lvl - xp_remaining.round.to_i
    [xp_current, xp_total_to_next_lvl]
  end

  def self.convert_character_sheet(charsheet_data)
    charsheet_data.each do |key, val|
      if CHAR_SHEET_INT_ATTRS.include?(key)
        charsheet_data[key] = val.to_i
      elsif CHAR_SHEET_RATIONAL_ATTRS.include?(key)
        charsheet_data[key] = val.to_r
      end
    end

    Parser.add_emojis_to(charsheet_data)
  end

  def self.add_emojis_to(textbox_data)
    textbox_data.transform_keys { "#{CHAR_SHEET_ATTR_TO_EMOJI[it]} #{it}".strip }
  end

  def process
    data = process_capture

    # Parse last 2 lines of screen i.e. current task and percentage
    current_task_lines = @capture[-2..]

    data[:current_task] = CurrentTask.new(
      text: current_task_lines.first.strip,
      percent_completed:
        Parser.parse_percent_time_left(current_task_lines.last).first
    )

    @data = data
  end

  private

  def initialize(file)
    @capture = File.readlines(file)
  end

  # rubocop:disable Metrics/MethodLength
  def textbox_data_symbol(textbox)
    case textbox.first[TITLE_MATCHER].strip # Title/header of textbox
    when HEADER[:charsheet]
      [parse_character_sheet(textbox), :charsheet]
    when HEADER[:equipment]
      [parse_equipment(textbox), :equipment]
    when HEADER[:plot]
      [parse_plot_development(textbox), :plot]
    when HEADER[:spells]
      [parse_spell_book(textbox), :spells]
    when HEADER[:inventory]
      [parse_inventory(textbox), :inventory]
    when HEADER[:quests]
      [parse_quests(textbox), :quests]
    end
  end
  # rubocop:enable Metrics/MethodLength

  def process_capture
    data = PqData.new

    textboxes(top_left_corners).each do |textbox|
      textbox_data, symbol = textbox_data_symbol(textbox)
      data[symbol] = textbox_data
    end

    data
  end

  def top_left_corners
    top_left_corners = []

    @capture.each_with_index do |line, row|
      top_left_corners << Parser.top_left_corners_from_line(line, row)
    end

    top_left_corners.flatten
  end

  def textboxes(top_left_corners)
    top_left_corners.map { |coords| one_textbox(coords.row, coords.col) }
  end

  # Get text for one textbox
  def one_textbox(first_row, first_col)
    # Last column of the textbox in the capture
    last_col =
      first_col + @capture[first_row].chars.drop(first_col).find_index('┐')

    first_col_chars =
      @capture[first_row..(@capture.size - 3)].map(&:chars).transpose[first_col]

    # Last row of the textbox in the capture
    last_row = first_row + first_col_chars.find_index('└')

    (first_row..last_row).map { |row| @capture[row][first_col..last_col] }
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

  def parse_experience_textbox(textbox)
    tb_xp = filter_textbox(textbox).select { it.size == 1 }.flatten
    xp_remaining = tb_xp.first[XP_REMAINING_MATCHER].to_i

    xp_percent, xp_time_left, xp_time_unit =
      Parser.parse_percent_time_left(tb_xp.last)
    [xp_remaining, xp_percent, xp_time_left, xp_time_unit]
  end

  def parse_experience(textbox)
    xp_remaining, xp_pct, time_left, time_unit =
      parse_experience_textbox(textbox)
    xp_current, xp_total_to_next_lvl = Parser.calc_xp(xp_remaining, xp_pct)

    { 'XP' => xp_current,
      'XP Needed' => xp_total_to_next_lvl,
      'XP Remaining' => xp_remaining,
      'XP (%)' => xp_pct,
      'Time Left (h)' => time_left,
      'Time Unit' => time_unit }
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
        completed: line[1] == 'X',
        text: line[3..].strip
      )
    end

    percent_completed, time_left, time_unit =
      Parser.parse_percent_time_left(filtered_tb.last)

    [tasks, percent_completed, time_left, time_unit]
  end

  def parse_character_sheet(textbox)
    return unless Parser.validate_textbox_header?(textbox, HEADER[:charsheet])

    char_data = parse_generic(textbox).merge(parse_experience(textbox))

    Parser.convert_character_sheet(char_data)
  end

  def parse_equipment(textbox)
    return unless Parser.validate_textbox_header?(textbox, HEADER[:equipment])

    parse_generic(textbox)
  end

  def parse_plot_development(textbox)
    return unless Parser.validate_textbox_header?(textbox, HEADER[:plot])

    acts, percent_completed, time_left, time_unit = parse_todo_list(textbox)

    {
      'Acts' => acts,
      'Completed %' => percent_completed,
      'Time Left' => time_left,
      'Time Unit' => time_unit
    }
  end

  def parse_spell_book(textbox)
    return unless Parser.validate_textbox_header?(textbox, HEADER[:spells])

    parse_generic(textbox).transform_values { RomanNumerals.to_decimal(it) }
  end

  def filter_inventory(textbox)
    filter_textbox(textbox).select { it.size == 1 }.flatten
  end

  def parse_inventory(textbox)
    return unless Parser.validate_textbox_header?(textbox, HEADER[:inventory])

    filtered_tb = filter_inventory(textbox)

    inv_data = { 'Items' => parse_generic(textbox).transform_values(&:to_i),
                 'Encumbrance (%)' =>
                    Parser.parse_percent_time_left(filtered_tb.last).first }

    inv_data['Inventory Spaces Filled'],
      inv_data['Inventory Spaces Max'] =
      INV_SPACES_MATCHER.match(filtered_tb.first).captures.map(&:to_i)

    inv_data
  end

  def parse_quests(textbox)
    return unless Parser.validate_textbox_header?(textbox, HEADER[:quests])

    quests, percent_completed, time_left, time_unit = parse_todo_list(textbox)

    {
      'Quests' => quests,
      'Completed %' => percent_completed,
      'Time Left' => time_left,
      'Time Unit' => time_unit
    }
  end
end
