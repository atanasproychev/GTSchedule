# encoding: utf-8
require 'nokogiri'
require 'prawn'
require 'open-uri'

module GT
  class GTSchedule
    def initialize(type, lines = :all)
      line_numbers = get_lines
      # p lines
      if lines.instance_of? Hash
        line_numbers.each_key do |type|
          if lines[type].nil?
            line_numbers[type] = []
          else
            line_numbers[type] &= lines[type]
          end
        end
      end
      @lines = {}
      @type = type
      # p line_numbers
      line_numbers.each do |type, numbers|
        line_objects = []
        numbers.each { |number| line_objects << Line.new(number, type) }
        @lines[type] = line_objects.sort { |line1, line2| line1.number.to_i <=> line2.number.to_i }
      end
      @lines
    end
    
    def get_lines
      document = GTSchedule.parse "Home.html"
      lines = {}
      sections = document.css(".lines_section")
      sections.each_with_index do |section, index|
        numbers = []
        sections[index].css("a").each { |line| numbers << line.text }
        type = case index
                 when 0
                   :tramway
                 when 1
                   :trolleybus
                 when 2, 3
                   :autobus
               end
        lines.merge!({type => numbers}) { |key, old, new| old + new }
      end
      lines
    end
  
    def self.parse(url = nil)
      # new_html = open("http://schedules.sofiatraffic.bg/autobus/102").read  #IO.read(File.expand_path("../../test102.html"))
      # p __FILE__
      html = IO.read(File.expand_path("../../../#{url}", __FILE__))
      document = Nokogiri::HTML::Document.parse(html, nil, "utf-8")
      
      #File.open(File.expand_path("../../test.txt")) { |file| new_html << file.read }
      
      #puts directions
      # document.css(".schedule_direction_view_course table")[0].css("th,td")
      # line = Line.new '102', :autobus, directions
      
      # times
      # Prawn::Document.generate("Proba.pdf") do
        # font_path = "#{Prawn::BASEDIR}/data/fonts/"
        # font_families.update('TimesNewRoman' => {:bold => font_path + 'timesbd.ttf',
                                                    # :italic => font_path + 'timesi.ttf',
                                                    # :bold_italic => font_path + 'timesbi.ttf',
                                                    # :normal => font_path + 'times.ttf'},
                                # 'CourierNew' => {:normal => font_path + 'cour.ttf'})
        # font 'TimesNewRoman'
        # text document.css("h3").text
      # end
    end
    
    def get_html_from(site)
      open(site).read
    end
    
  end
  
  class MyTime
    def initialize(time)
      time.match /(\d?\d):(\d\d)/
      @hours = $1
      @minutes = $2
    end
    
    def +(minutes)
      @minutes += minutes
      if @minutes >= 60
        @hours++
        @minutes = @minutes % 60
      end
    end
    
    def self.minutes_to_min_sec(minutes)
      min = minutes.to_i
      sec = (minutes - min) * 100
      sec *= 0.6
      "#{min}:#{sec.to_i}"
    end
    
    def to_s
      "#@hours:#@minutes"
    end
  end
  
  class Course
    attr_accessor :course_times
  
    def initialize(begins, course_times, incomplete = false)
      @begins = MyTime.new begins
      @course_times = get_times_from course_times
      # p @course_times
      @incomplete = incomplete
    end
    
    def get_times_from(course_times)
      @vehicle = 0;
      course_times.match(/Raz.exec \('show_course', \['.{9}', '(.+?)'\]\); return false;/)
      course_times = $1
      course_times = course_times.split(',').map { |elem| elem.to_i }
      @vehicle = course_times.shift
      (1...course_times.length).each { |index| course_times[index] -= course_times[0] }
      course_times[0] = 0
      course_times
    end
    
    def to_s
      @begins
      # p @time
    end
  end
  
  class Direction
    attr_accessor :course_list, :station_list

    def initialize(name, time_to = nil)
      @name = name
      @course_list = []
      @station_list = []
    end
    
    def average_course_times
      # p @course_list.flatten
      course_times = @course_list.flatten.map { |course| course.course_times }
      # p test
      all = []
      # p max_length test
      max_length(course_times).times do |number|
        arr = []
        course_times.map! do |array|
          arr << array.shift
          array
        end
        all << arr.compact
      end
      all.map do |elem|
        (elem.inject(0.0, :+) / elem.length).round(2)
      end
      # p test, all
      #p test.transpose
    end
    
    def max_length(array)
      return 0 if array.first.nil?
      max = array.first.length
      array.each { |arr| max = arr.length > max ? arr.length : max }
      max
    end
    
    def to_s
      "#@name\n#@station_list\n#@time_list"
    end
  end
  
  class Station
    def initialize(name, number)
      @name, @number = name, number
    end
    
    def to_s
      "#@number #@name"
    end
  end
  
  class Line
    attr_accessor :number
    
    def initialize(number, type, directions = [])
      @number, @type, @directions = number, type, directions
      get_directions if @directions == []
      # @directions.map { |dir| puts dir }
    end
    
    def get_directions
      @document = GTSchedule.parse "Line102.html"
      
      @froms = []
      @document.css("h3 em").each { |date| @froms << date.text }
      @directions = []
      all_directions = @document.css(".schedule_view_direction_tabs li a span")
      number_of_directions_per_day = all_directions.length / @froms.length
      0.upto(number_of_directions_per_day - 1).each { |number| @directions[number] = Direction.new all_directions[number].text }
      type_number = 1;
      @directions.each_with_index do |direction, index|
        index_special = index + number_of_directions_per_day * type_number
        times = @document.css(".schedule_times")[index_special].css(".hours_cell")
        course_list = []
        times.each do |hour|
          hour_list = []
          hour.children.each do |time|
            time_as_string = time.text.strip
            unless time_as_string.empty?
              next if time_as_string == "\u00A0"
              #p time_as_string
              hour_list << Course.new(time_as_string, time['onclick'], time['class'] == 'incomplete_course')
            end
          end
          course_list << hour_list
        end
        p direction.course_list = course_list
        stops = @document.css(".schedule_direction_view_course table")[index_special].css("th,td")
        station_list = []
        stops.each_slice(3) do |array|
          stop = array.first.text
          if stop.match /\A(.+) \| (\d+)/
            station_list << Station.new($1, $2)
          else
            next
          end
        end
        direction.station_list = station_list
        direction.average_course_times.each { |minutes| MyTime.minutes_to_min_sec minutes }
      end
      # p @directions.length
    end
    
    def to_s
      "#@type  #@number"
    end
  end
end


GT::GTSchedule.new :week, :autobus => ['102']#, :autobus => ['1', '5', '204'], :trolleybus => ['2', '9'], :tramway => ['10']
# GT::GTSchedule.parse
# GT::Course.new '8:55', "Raz.exec ('show_course', ['1c79b7fbb', '10,535,536,538,539,540,541,542,543,544,547,548,,,,,,,,,,,,,,,,,,,,,,,']); return false;"