require 'pry'

class ToolService
  include ConnectToCanvas
  attr_accessor :all_course_data, :environment, :term_id, :account_id, :enrollment_term, :all_courses, :canvas, :host_url, :announcement_dates

  def initialize(environment, term_id, account_id, current_user)
    # decrypt Canvas token
    crypt = ActiveSupport::MessageEncryptor.new(ENV['KEY'])
    canvas_token = current_user.canvas_token
    unencrypted_canvas_token = crypt.decrypt_and_verify(canvas_token)

    # define
    @host_url = self.get_host_url(environment)
    @canvas = self.connect_to_canvas_api(@host_url, unencrypted_canvas_token)

    begin
      @canvas = self.connect_to_canvas_api(@host_url, unencrypted_canvas_token)
      @enrollment_term = self.get_enrollment_term(term_id, @canvas)
      @all_courses = self.get_all_courses(account_id, @enrollment_term, @canvas)
      @announcement_dates = self.get_announcement_dates(term_id)
      @courses_data = [] # create the array to hold all the course data
      @all_tool_ids = Lti.all.map {|a| a['tool_id']}
    rescue
      @canvas = nil
    end
  end

  def get_enrollment_term(term_id, canvas)
    # Determine enrollment term id from sis id
    @enrollment_term = 0 # default

    all_terms = @canvas.get("/api/v1/accounts/1/terms?workflow_state[]=all&per_page=100")
    all_terms["enrollment_terms"].each do |term|
      if term["name"] == term_id
        @enrollment_term = term["id"]
      end
    end
    return @enrollment_term
  end

  def get_all_courses(account_id, enrollment_term, canvas) # Create an array with all courses in the given term and account
    @all_courses = Array.new

    courses =  @canvas.get("/api/v1/accounts/#{account_id}/courses?with_enrollments=true&enrollment_term_id=#{enrollment_term}")

    while courses.more? == true
      courses.next_page!
    end
    courses.each do |course|
      @all_courses << course["id"]
    end
  end

  def get_announcement_dates(term_id)
    # Define start and end date for announcements
    if term_id.include? "Spring"
      beg_month = "01"
      beg_day = "01"
      fin_month = "05"
      fin_day = "25"
    elsif term_id.include? "Summer"
      beg_month = "05"
      beg_day = "26"
      fin_month = "08"
      fin_day = "15"
    elsif term_id.include? "Fall"
      beg_month = "08"
      beg_day = "16"
      fin_month = "12"
      fin_day = "31"
    elsif term_id.include? "YSS A"
      beg_month = "05"
      beg_day = "25"
      fin_month = "07"
      fin_day = "01"
    elsif term_id.include? "YSS B"
      beg_month = "07"
      beg_day = "01"
      fin_month = "08"
      fin_day = "10"
    else
      beg_month = "01"
      beg_day = "01"
      fin_month = "12"
      fin_day = "31"
    end

    # Year
    year_raw = term_id.gsub(/[^0-9]/, '')
    if year_raw.length == 2
      beg_year = fin_year = "20" + year_raw
    elsif year_raw == nil
      beg_year = "2008"
      fin_year = Date.today.year.to_s
    else
      beg_year = fin_year = year_raw
    end

    beg = beg_year.to_s + "-" + beg_month.to_s + "-" + beg_day.to_s
    fin = fin_year.to_s + "-" + fin_month.to_s + "-" + fin_day.to_s

    @announcement_dates = "&start_date=#{beg}&end_date=#{fin}"
  end

  def get_instructor_names(course_id)
    all_instructors = @canvas.get("/api/v1/courses/#{course_id}/users?enrollment_role_id=9")
    instructor_arr = Array.new
    all_instructors.each do |instructor|
      instructor_arr.push(instructor["name"])
    end
    @instructor_names = instructor_arr.map { |x| x}.join(", ")
  end

  def run_tool_report(enrollment_term, account_id, all_courses, announcement_dates, canvas, host_url, term_id)
    @all_course_data = Array.new # create the array that is going to hold the hashes of course data for each of the courses

    all_courses.each do |each_course| # run all the queries

      # Course ID
      course_id = each_course["id"]

      # Course URL
      url = host_url + "/courses/" + course_id.to_s
      @course_url = "<a href=#{url}>#{course_id}</a>"

      # List data per course:
      course = @canvas.get("/api/v1/courses/#{course_id}")

      # Course Code
      @course_code = course["course_code"]

      # Course Name
      @course_name = course["name"]

      # Link to course
      @course_url = @host_url + "/courses/" + course_id.to_s

      # Course Status
      @course_status = course["workflow_state"] # available, unpublished, etc.

      # Instructor(s) Names
      @instructor_names = get_instructor_names(course_id)

      # Sections Count
      @sections_count = @canvas.get("/api/v1/courses/#{course_id}/sections?&per_page=100").length

      # Role Ids
      main_roles = {
        9=>"instructors",
        5=>"tas",
        3=>"students",
        10=>"shoppers",
        11=>"auditors"
      }

      # Count each role
      @role_counts = {}
      main_roles.each do |role_id, role_name|
        users_with_role = @canvas.get("/api/v1/courses/#{course_id}/users?enrollment_role_id=#{role_id}")
        while users_with_role.more? == true
          users_with_role.next_page!
        end
        @role_counts["#{role_name}"] = users_with_role.length
      end

      if @course_status == "available" # Only do the following if the course is published

        # Groups Count
        @groups_count = @canvas.get("/api/v1/courses/#{course_id}/groups?&per_page=100").length

        secondary_roles = {
          13=>"guest_students",
          4=>"teachers",
          12=>"guest_instructors",
          25=>"librarians",
          6=>"designers",
          7=>"observers",
          19=>"viewers",
          26=>"graders"}

        # Count each role
        secondary_roles.each do |role_id, role_name|
          users_with_role = @canvas.get("/api/v1/courses/#{course_id}/users?enrollment_role_id=#{role_id}")

          # while users_with_role.more? == true
          #   users_with_role.next_page!
          # end

          @role_counts["#{role_name}"] = users_with_role.length
        end

        # Announcements
        begin
          @announcement_count = @canvas.get("/api/v1/announcements?context_codes[]=course_#{course_id}#{announcement_dates}&per_page=100").length
        rescue
          @announcement_count = ""
        end

        # Assignments Count
        @assignment_count = @canvas.get("/api/v1/courses/#{course_id}/assignments?&per_page=100").length

        # Discussion Topics Count
        @discussion_topic_count = @canvas.get("/api/v1/courses/#{course_id}/discussion_topics?&per_page=100").length

        # Discussion Responses Count
        discussions = @canvas.get("/api/v1/courses/#{course_id}/discussion_topics?&per_page=100")
        @discussion_responses_count = 0
        discussions.each do |discussion|
          @discussion_responses_count = @discussion_responses_count + discussion["discussion_subentry_count"].to_i
        end

        # Pages Count (published)
        pages = @canvas.get("/api/v1/courses/#{course_id}/pages?published=true&per_page=100")
        while pages.more? == true
          pages.next_page!
        end
        @published_pages = pages.length

        # Files Count
        all_files = @canvas.get("/api/v1/courses/#{course_id}/files?published=true?&per_page=100")
        while all_files.more? == true
          all_files.next_page!
        end
        @files_count = all_files.length

        # Files Quota Used (in MB)
        @files_quota_used = @canvas.get("/api/v1/courses/#{course_id}/files/quota")["quota_used"]/1000000.00

        # Syllabus # need info on published state too? #broken?
        syllabus_course_info = @canvas.get("/api/v1/courses/#{course_id}?include[]=syllabus_body")
        if syllabus_course_info["syllabus_body"] == nil
          @syllabus = false
        else
          @syllabus = true
        end

        # Quizzes Count
        @quizzes_count = @canvas.get("/api/v1/courses/#{course_id}/quizzes?&per_page=100").length

        # Modules Count
        @modules_count = @canvas.get("/api/v1/courses/#{course_id}/modules?&per_page=100").length

        # External Tools
        course_tools = @canvas.get("/api/v1/courses/#{course_id}/tabs") # Get json of all tools in course
        ext_tools = Array.new # create an array to hold the ids of the course tools in use

        course_tools.each do |tool|
          if tool["type"] == "external" && tool["hidden"] == nil # if it's an external tool and not hidden
            full_id = tool["id"]
            id = full_id.gsub("context_external_tool_", "") # remove "context_external_tool_" from id
            ext_tools << id.to_i # add external tool ids to the new array
          end
        end

        tool_names = Array.new # create an array to hold the names of tools used in this course
        ext_tools.each do |id| # for each of this course's external tool ids
          if @all_tool_ids.include?(id) # if the master tool id list contains the id of this course's external tools
            tool_names << Lti.find_by(:tool_id => id).name # add the name of the LTI to a new array
          end
        end

        lti_results = Hash.new # create a new hash to store data about each tool

        tool_names.each do |name|
          if name.include?("Moodle")
            name = "Moodle"
          elsif name.include?("Faculty Enlight")
            name = "Faculty Enlight"
          end
          lti_results["#{name}"] = true
        end

        # create a hash with this course's data
        course_data = Hash.new
        course_data = {
          'code' => @course_code,
          'name' => @course_name,
          'id' => @course_url,
          'stat' => @course_status,
          'instrnms' => @instructor_names,
          'sect#' => @sections_count,
          'grp#' => @groups_count,
          'instr#' => @role_counts['instructors'],
          'TA#' => @role_counts['tas'],
          'stud#' => @role_counts['students'],
          'shop#' => @role_counts['shoppers'],
          'aud#' => @role_counts['auditors'],
          'ann#' => @announcement_count,
          'ass#' => @assignment_count,
          'dsctop#' => @discussion_topic_count,
          'dscrsp#' =>  @discussion_responses_count,
          'pubpgs' => @published_pages,
          'file#' => @files_count,
          'filesze' => @files_quota_used,
          'syll' => @syllabus,
          'quiz#' => @quizzes_count,
          'mod#' => @modules_count,
          'chat' => lti_results["Chat"] || "false",
          'crsres' => lti_results["Course Reserves"] || "false",
          'emllst' => lti_results["Email Lists"] || "false",
          'fbck' => lti_results["Feedback"] || "false",
          'medlib' => lti_results["Media Library"] || "false",
          'phoros' => lti_results["Photo Roster"] || "false",
          'pzza' => lti_results["Piazza"] || "false",
          'pstem' => lti_results["Post'Em"] || "false",
          'roll_call' => lti_results["Roll Call"] || "false",
          'tchrs' => @role_counts['teachers'],
          'libs' => @role_counts['librarians'],
          'gstinstr' => @role_counts['guest_instructors'],
          'vwrs' => @role_counts['viewers'],
          'obsrv' => @role_counts['observers'],
          'gststud' => @role_counts['guest_students'],
          'grdr' => @role_counts['graders']}

      else
        # create a hash with this course's data
        course_data = Hash.new
        course_data = {
          'code' => @course_code,
          'name' => @course_name,
          'id' => @course_url,
          'stat' => @course_status,
          'instrnms' => @instructor_names,
          'sect#' => @sections_count,
          'instr#' => @role_counts['instructors'],
          'TA#' => @role_counts['tas'],
          'stud#' => @role_counts['students'],
          'shop#' => @role_counts['shoppers'],
          'aud#' => @role_counts['auditors']
          }

      end

      @each_course_data = @courses_data.push(course_data) # add this course's data to the array of all course data
      @all_course_data << @each_course_data

    end # all_courses.each do |each_course|

    return @all_course_data

    # Delayed::Job.where id = @tool.delayed_job_id
    #
    # last.Tool.all_course_data = @all_course_data

  end # def run_tool_report
  # handle_asynchronously :run_tool_report
end # class ToolService
