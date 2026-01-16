# frozen_string_literal: true

# Contains all constants and "class methods" for the parser
module PqCliParse
  HEADER = { charsheet: 'Character Sheet', equipment: 'Equipment',
             plot: 'Plot Development', spells: 'Spell Book',
             inventory: 'Inventory', quests: 'Quests' }.freeze

  CHAR_SHEET_ATTRS = {
    integer: ['Level', 'STR', 'CON', 'DEX', 'INT', 'WIS', 'CHA', 'HP Max',
              'MP Max', 'XP', 'XP Needed', 'XP Remaining'],
    rational: ['XP (%)', 'Time Left (h)']
  }.freeze

  CHAR_SHEET_ATTR_TO_EMOJI = { 'Name' => '❝', 'Race' => '🏁', 'Class' => '✍️',
                               'Level' => '📈', 'STR' => '💪', 'CON' => '🩸',
                               'DEX' => '🤌', 'INT' => '🧠', 'WIS' => '🧓',
                               'CHA' => '😍', 'HP Max' => '❤️',
                               'MP Max' => '🪄' }.freeze

  REGEX_MATCHER = { inventory_spaces: %r{(\d+)?/(\d+)}, number: /(\d*\.?\d+)/,
                    time: /(\d*\.?\d+).*([a-zA-Z]+)/, title: /([ \w]+)/,
                    top_left_corner: /(?=┌)/, xp_remaining: /(\d+)/ }.freeze

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

  @xp_current_cached = 0
  @xp_total_cached = 0

  module_function

  def top_left_corners_from_line(line, row_number)
    indices_top_left =
      line.enum_for(:scan, REGEX_MATCHER[:top_left_corner]).map do
        Regexp.last_match.offset(0).first
      end

    indices_top_left.map do |col|
      Coordinates.new(row: row_number, col: col)
    end
  end

  def textboxes(top_left_corners)
    top_left_corners.map { one_textbox(it.row, it.col) }
  end

  def validate_textbox_header?(textbox, header)
    textbox.first[REGEX_MATCHER[:title]].strip == header
  end

  def parse_percent_time_left(line)
    split_line = line.strip.split

    percent = split_line.first[REGEX_MATCHER[:number]].to_r

    time_left, time_unit =
      if split_line.size == 2
        REGEX_MATCHER[:time].match(split_line.last).captures
      else
        [0, 'm']
      end

    [percent, time_left.to_r, time_unit]
  end

  def calc_xp(xp_remaining, xp_percent)
    unless xp_percent.to_r == 100r || xp_remaining.zero?
      # Normal behaviour when no zero division error imminent
      xp_total_to_next_lvl =
        (xp_remaining / ((100r - xp_percent)/100r)).round.to_i
      xp_current = xp_total_to_next_lvl - xp_remaining.round.to_i

      @xp_total_cached = xp_total_to_next_lvl
      @xp_current_cached = xp_current
    else
      # When XP% is 100% or XP %emaining is 0, current XP = total XP required
      @xp_current_cached = @xp_total_cached
    end

    [@xp_current_cached, @xp_total_cached]
  end

  def convert_character_sheet(charsheet_data)
    charsheet_data.each do |key, val|
      if CHAR_SHEET_ATTRS[:integer].include?(key)
        charsheet_data[key] = val.to_i
      elsif CHAR_SHEET_ATTRS[:rational].include?(key)
        charsheet_data[key] = val.to_r
      end
    end

    add_emojis_to(charsheet_data)
  end

  def add_emojis_to(textbox_data)
    textbox_data.transform_keys do |key|
      if CHAR_SHEET_ATTR_TO_EMOJI.key?(key)
        "#{CHAR_SHEET_ATTR_TO_EMOJI[key]} #{key}"
      else
        key
      end
    end
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

  # Many entries in the boxes are basically:
  # SomethingOnTheLeft.......................................SomethingOnTheRight
  # This parses these 2 value entries as key-value pairs
  def parse_generic(textbox)
    filter_textbox(textbox).select { it.size == 2 }.to_h
  end

  def parse_experience_textbox(textbox)
    tb_xp = filter_textbox(textbox).select { it.size == 1 }.flatten
    xp_remaining = tb_xp.first[REGEX_MATCHER[:xp_remaining]].to_i

    xp_percent, xp_time_left, xp_time_unit =
      parse_percent_time_left(tb_xp.last)
    [xp_remaining, xp_percent, xp_time_left, xp_time_unit]
  end

  def parse_experience(textbox)
    xp_remaining, xp_pct, time_left, time_unit =
      parse_experience_textbox(textbox)
    xp_current, xp_total_to_next_lvl = calc_xp(xp_remaining, xp_pct)

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
      parse_percent_time_left(filtered_tb.last)

    [tasks, percent_completed, time_left, time_unit]
  end

  def parse_character_sheet(textbox)
    return unless validate_textbox_header?(textbox, HEADER[:charsheet])

    char_data = parse_generic(textbox).merge(parse_experience(textbox))

    convert_character_sheet(char_data)
  end

  def parse_equipment(textbox)
    return unless validate_textbox_header?(textbox, HEADER[:equipment])

    parse_generic(textbox)
  end

  def parse_plot_development(textbox)
    return unless validate_textbox_header?(textbox, HEADER[:plot])

    acts, percent_completed, time_left, time_unit = parse_todo_list(textbox)

    {
      'Acts' => acts,
      'Completed %' => percent_completed,
      'Time Left' => time_left,
      'Time Unit' => time_unit
    }
  end

  def parse_spell_book(textbox)
    return unless validate_textbox_header?(textbox, HEADER[:spells])

    parse_generic(textbox).transform_values { RomanNumerals.to_decimal(it) }
  end

  def filter_inventory(textbox)
    filter_textbox(textbox).select { it.size == 1 }.flatten
  end

  def parse_inventory(textbox)
    return unless validate_textbox_header?(textbox, HEADER[:inventory])

    filtered_tb = filter_inventory(textbox)

    inv_data = { 'Items' => parse_generic(textbox).transform_values(&:to_i),
                 'Encumbrance (%)' =>
                    parse_percent_time_left(filtered_tb.last).first }

    inv_data['Inventory Spaces Filled'], inv_data['Inventory Spaces Max'] =
      REGEX_MATCHER[:inventory_spaces].match(filtered_tb.first)
                                      .captures
                                      .map(&:to_i)

    inv_data
  end

  def parse_quests(textbox)
    return unless validate_textbox_header?(textbox, HEADER[:quests])

    quests, percent_completed, time_left, time_unit = parse_todo_list(textbox)

    {
      'Quests' => quests,
      'Completed %' => percent_completed,
      'Time Left' => time_left,
      'Time Unit' => time_unit
    }
  end

  HEADER_TO_PARSED_SYMBOL = {
    HEADER[:charsheet] =>
      ->(textbox) { [parse_character_sheet(textbox), :charsheet] },
    HEADER[:equipment] =>
      ->(textbox) { [parse_equipment(textbox), :equipment] },
    HEADER[:plot] => ->(textbox) { [parse_plot_development(textbox), :plot] },
    HEADER[:spells] => ->(textbox) { [parse_spell_book(textbox), :spells] },
    HEADER[:inventory] =>
      ->(textbox) { [parse_inventory(textbox), :inventory] },
    HEADER[:quests] => ->(textbox) { [parse_quests(textbox), :quests] }
  }.freeze

  def parse_textbox_data_and_symbol(textbox)
    title = textbox.first[REGEX_MATCHER[:title]].strip
    HEADER_TO_PARSED_SYMBOL[title].call(textbox)
  end
end
