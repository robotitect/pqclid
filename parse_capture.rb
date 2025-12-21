capture = File.open(ARGV[0]) 

Coordinates = Struct.new(:x, :y)
Box = Struct.new(:top_left, :top_right, :bot_left, :bot_right)

Boxes = Array.new

capture.each do |line|
  indices_top_left = line.enum_for(:scan, /(?=┌)/).map do 
    Regexp.last_match.offset(0).first
  end    
  
  puts indices_top_left
end

