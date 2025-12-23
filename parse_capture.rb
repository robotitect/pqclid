require 'awesome_print'

HEADER_CHAR_SHEET = 'Character Sheet'
HEADER_EQUIPMENT = 'Equipment'
HEADER_PLOT_DEV = 'Plot Development'
HEADER_SPELL_BOOK = 'Spell Book'
HEADER_INVENTORY = 'Inventory'
HEADER_QUESTS = 'Quests'

CHAR_SHEET_INT_ATTRS =
  ['Level', 'STR', 'CON', 'DEX', 'INT', 'WIS', 'CHA', 'HP Max', 'MP Max', 'XP',
   'XP Remaining']

CHAR_SHEET_FLOAT_ATTRS = ['XP (%)', 'Time Left (h)']


Coordinates = Struct.new(:row, :col)
Box = Struct.new(:top_left, :top_right, :bot_left, :bot_right)

capture = File.readlines(ARGV[0])

top_left_corners = []

capture.each_with_index do |line, row|
  indices_top_left = line.enum_for(:scan, /(?=┌)/).map do
    Regexp.last_match.offset(0).first
  end

  indices_top_left.each do |col|
    top_left_corners << Coordinates.new(row, col)
  end
end

# Get text for all boxes
textboxes = []

top_left_corners.each do |coords|
  first_row = coords.row
  first_col = coords.col

  # Go right until get top right corner
  last_col =
    first_col + capture[first_row].split('').drop(first_col).find_index('┐')

  # Go down until get bot left corner
  last_row = first_row
  (first_row...capture.size).each do |row|
    char = capture[row].split('')[first_col]
    if char == '└'
      last_row = row
      break
    end
  end

  # Extract each line based on corners
  textbox = []
  (first_row..last_row).each do |r|
    textbox << capture[r][first_col..last_col]
  end

  # puts textbox
  textboxes << textbox
end

def filter_textbox(textbox)
  # Skip first and last lines (just ----------------)
  textbox[1..-2].map { |line| line[1..-2].split('  ') } # Split along long lengths of spaces
                .map { |line| line.map(&:strip).reject { _1 == '' } } # Remove empty strings
                .compact # Remove nils
end

def parse_generic(textbox)
  filter_textbox(textbox).reject { _1.size != 2 }.to_h
end

def parse_character_sheet(textbox)
  return unless textbox.first[/([ \w]+)/].strip == HEADER_CHAR_SHEET

  char_data = parse_generic(textbox)

  # TODO: handle Experience
  tb_xp = filter_textbox(textbox).reject { _1.size != 1 }.flatten
  ap tb_xp
  xp_remaining = tb_xp.first[/([\d]+)/].to_f
  xp_percent = tb_xp.last[/([\d]+).([\d]+)/].to_f
  regexp_time_left = /\d+.\d+.+(\d+.\d+)/
  xp_time_left = regexp_time_left.match(tb_xp.last).captures.first
  ap xp_time_left

  xp_total =
    (xp_remaining.to_f / ((100.0 - xp_percent.to_f) / 100.0)).round.to_i

  char_data["XP"] = xp_total.to_i - xp_remaining.round.to_i
  char_data["XP Remaining"] = xp_remaining
  char_data["XP (%)"] = xp_percent
  char_data["Time Left (h)"] = xp_time_left

  char_data.each do |attr, val|
    if CHAR_SHEET_INT_ATTRS.include?(attr)
      char_data[attr] = val.to_i
    end

    if CHAR_SHEET_FLOAT_ATTRS.include?(attr)
      char_data[attr] = val.to_f
    end
  end

  # puts "XP remaining: #{xp_remaining}"
  # puts "XP total: #{xp_total}"
  # puts "XP%: #{xp_percent}"

  char_data
end

def parse_equipment(textbox)
  return unless textbox.first[/([ \w]+)/].strip == HEADER_EQUIPMENT

  parse_generic(textbox)
end

def parse_plot_development(textbox)
  return unless textbox.first[/([ \w]+)/].strip == HEADER_PLOT_DEV
end

def parse_spell_book(textbox)
  return unless textbox.first[/([ \w]+)/].strip == HEADER_SPELL_BOOK

  parse_generic(textbox)
end

def parse_inventory(textbox)
  return unless textbox.first[/([ \w]+)/].strip == HEADER_INVENTORY
end

def parse_quests(textbox)
  return unless textbox.first[/([ \w]+)/].strip == HEADER_QUESTS
end

textboxes[0..0].each_with_index do |textbox, i|
  title = textbox.first[/([ \w]+)/].strip
  puts "\nBox #{i}: #{title}"
  textbox_data =
    case title
    when HEADER_CHAR_SHEET
      parse_character_sheet(textbox)
    when HEADER_EQUIPMENT
      parse_equipment(textbox)
    when HEADER_PLOT_DEV
      parse_plot_development(textbox)
    when HEADER_SPELL_BOOK
      parse_spell_book(textbox)
    when HEADER_INVENTORY
      parse_inventory(textbox)
    when HEADER_QUESTS
      parse_quests(textbox)
    end

  ap textbox_data
end
