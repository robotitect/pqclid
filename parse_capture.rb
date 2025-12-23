require "awesome_print"

HEADER_CHAR_SHEET = "Character Sheet"
HEADER_EQUIPMENT = "Equipment"
HEADER_PLOT_DEV = "Plot Development"
HEADER_SPELL_BOOK = "Spell Book"
HEADER_INVENTORY = "Inventory"
HEADER_QUESTS = "Quests"

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
    first_col + capture[first_row].split("").drop(first_col).find_index('┐')

  # Go down until get bot left corner
  last_row = first_row
  (first_row...capture.size).each do |row|
    char = capture[row].split("")[first_col]
    if char == '└'
        last_row = row
        break
    end
  end

  # Extract each line based on corners
  textbox = Array.new()
  (first_row..last_row).each do |r|
    textbox << capture[r][first_col..last_col]
  end

  # puts textbox
  textboxes << textbox
end

def filter_textbox(textbox)
  # Skip first and last lines (just ----------------)
  textbox[1..-2].map { |line| line[1..-2].split("  ") } # Split along long lengths of spaces
                .map { |line| line.map(&:strip).reject { _1 == "" }} # Remove empty strings
                .compact # Remove nils
end

def parse_generic(textbox)
  textbox_data = {}
  filter_textbox(textbox).each do |line|
    if line.size == 2
      textbox_data[line.first] = line.last
    end
  end
  textbox_data
end

def parse_character_sheet(textbox)
  return unless textbox.first[/([ \w]+)/].strip == HEADER_CHAR_SHEET

  textbox_data = {}

  filter_textbox(textbox).each do |line|
    if line.size == 2
      textbox_data[line.first] = line.last
    end
  end

  # TODO: handle Experience

  textbox_data
end

def parse_equipment(textbox)
  return unless textbox.first[/([ \w]+)/].strip == HEADER_EQUIPMENT

  textbox_data = parse_generic(textbox)

  textbox_data
end

def parse_plot_development(textbox)
end

def parse_spell_book(textbox)
  if textbox.first[/([ \w]+)/].strip != HEADER_SPELL_BOOK
    return
  end

  textbox_data = parse_generic(textbox)

  textbox_data
end

def parse_inventory(textbox)
end

def parse_quests(textbox)
end

textboxes.each_with_index do |textbox, i|

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

