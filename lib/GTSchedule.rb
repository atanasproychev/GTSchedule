# encoding: utf-8
require 'nokogiri'
require 'prawn'
require 'open-uri'

module GT
  class GTSchedule
    def self.parse(html = nil)
      # new_html = open("http://schedules.sofiatraffic.bg/autobus/102").read  #IO.read(File.expand_path("../../test102.html"))
      new_html = IO.read(File.expand_path("../../test102.html"))
      document = Nokogiri::HTML::Document.parse(new_html, nil, "utf-8")
      
      #File.open(File.expand_path("../../test.txt")) { |file| new_html << file.read }
      froms = []
      document.css("h3 em").each { |date| froms << date.text }
      directions = []
      all_directions = document.css(".schedule_view_direction_tabs li a span")
      0.upto(all_directions.length / froms.length - 1).each { |number| directions[number] = Direction.new all_directions[number].text }
      directions.each_with_index do |direction, index|
        times = document.css(".schedule_times")[index].css(".hours_cell")
        course_list = []
        times.each do |hour|
          hour_list = []
          hour.children.each do |time|
            time_as_string = time.text.strip
            unless time_as_string.empty?
              next if time_as_string == "\u00A0"
              # p time_as_string
              hour_list << Course.new(time_as_string, time['onclick'], time['class'] == 'incomplete_course')
            end
          end
          course_list << hour_list
        end
        direction.course_list = course_list
        stops = document.css(".schedule_direction_view_course table")[index].css("th,td")
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
        direction.average_course_times.each { |minutes| p MyTime.minutes_to_min_sec minutes }
      end
      #puts directions
      document.css(".schedule_direction_view_course table")[0].css("th,td")
      line = Line.new '102', :autobus, directions
      
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
    def initialize(number, type, directions)
    end
  end
end


GT::GTSchedule.parse
# GT::Course.new '8:55', "Raz.exec ('show_course', ['1c79b7fbb', '10,535,536,538,539,540,541,542,543,544,547,548,,,,,,,,,,,,,,,,,,,,,,,']); return false;"