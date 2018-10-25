require "thor"
require "chronic"
require "chronic_duration"
require "launchy"

require "calendar_assistant/cli_helpers"

class CalendarAssistant
  class CLI < Thor
    default_config = CalendarAssistant::Config.new options: options # used in option descriptions

    #  it's unfortunate that thor does not support this usage of help args
    class_option :help,
                 type: :boolean,
                 aliases: ["-h", "-?"]

    #  note that these options are passed straight through to CLIHelpers.print_events
    class_option :profile,
                 type: :string,
                 desc: "the profile you'd like to use (if different from default)",
                 aliases: ["-p"]
    class_option :debug,
                 type: :boolean,
                 desc: "how dare you suggest there are bugs"


    desc "authorize PROFILE_NAME",
         "create (or validate) a profile named NAME with calendar access"
    long_desc <<~EOD
      Create and authorize a named profile (e.g., "work", "home",
      "flastname@company.tld") to access your calendar.

      When setting up a profile, you'll be asked to visit a URL to
      authenticate, grant authorization, and generate and persist an
      access token.

      In order for this to work, you'll need to follow the
      instructions at this URL first:

      > https://developers.google.com/calendar/quickstart/ruby

      Namely, the prerequisites are:
      \x5 1. Turn on the Google API for your account
      \x5 2. Create a new Google API Project
      \x5 3. Download the configuration file for the Project, and name it as `credentials.json`
    EOD
    def authorize profile_name
      return if handle_help_args
      CalendarAssistant.authorize profile_name
      puts "\nYou're authorized!\n\n"
    end


    desc "show [DATE | DATERANGE | TIMERANGE]",
         "Show your events for a date or range of dates (default 'today')"
    option :commitments,
           type: :boolean,
           desc: "only show events that you've accepted with another person",
           aliases: ["-c"]
    def show datespec="today"
      return if handle_help_args
      config = CalendarAssistant::Config.new options: options
      ca = CalendarAssistant.new config
      events = ca.find_events CLIHelpers.parse_datespec(datespec)
      CLIHelpers::Out.new.print_events ca, events, options
    end


    desc "join [TIME]",
         "Open the URL for a video call attached to your meeting at time TIME (default 'now')"
    option :join,
           type: :boolean, default: true,
           desc: "launch a browser to join the video call URL"
    def join timespec="now"
      return if handle_help_args
      config = CalendarAssistant::Config.new options: options
      ca = CalendarAssistant.new config
      event, url = CLIHelpers.find_av_uri ca, timespec
      if event
        CLIHelpers::Out.new.print_events ca, event, options
        CLIHelpers::Out.new.puts url
        if options[:join]
          CLIHelpers::Out.new.launch url
        end
      else
        CLIHelpers::Out.new.puts "Could not find a meeting '#{timespec}' with a video call to join."
      end
    end


    desc "location [DATE | DATERANGE]",
         "Show your location for a date or range of dates (default 'today')"
    def location datespec="today"
      return if handle_help_args
      config = CalendarAssistant::Config.new options: options
      ca = CalendarAssistant.new config
      events = ca.find_location_events CLIHelpers.parse_datespec(datespec)
      CLIHelpers::Out.new.print_events ca, events, options
    end


    desc "location-set LOCATION [DATE | DATERANGE]",
         "Set your location to LOCATION for a date or range of dates (default 'today')"
    def location_set location, datespec="today"
      return if handle_help_args
      config = CalendarAssistant::Config.new options: options
      ca = CalendarAssistant.new config
      events = ca.create_location_event CLIHelpers.parse_datespec(datespec), location
      CLIHelpers::Out.new.print_events ca, events, options
    end

    desc "availability [DATE | DATERANGE | TIMERANGE]",
         "Show your availability for a date or range of dates (default 'today')"
    option CalendarAssistant::Config::Keys::Settings::MEETING_LENGTH,
           type: :string,
           banner: "LENGTH",
           desc: sprintf("[default %s] find chunks of available time at least as long as LENGTH (which is a ChronicDuration string like '30m' or '2h')",
                         default_config.setting(CalendarAssistant::Config::Keys::Settings::MEETING_LENGTH)),
           aliases: ["-l"]
    option CalendarAssistant::Config::Keys::Settings::START_OF_DAY,
           type: :string,
           banner: "TIME",
           desc: sprintf("[default %s] find chunks of available time after TIME (which is a Chronic string like '9am' or '14:30')",
                         default_config.setting(CalendarAssistant::Config::Keys::Settings::START_OF_DAY)),
           aliases: ["-s"]
    option CalendarAssistant::Config::Keys::Settings::END_OF_DAY,
           type: :string,
           banner: "TIME",
           desc: sprintf("[default %s] find chunks of available time before TIME (which is a Chronic string like '9am' or '14:30')",
                         default_config.setting(CalendarAssistant::Config::Keys::Settings::END_OF_DAY)),
           aliases: ["-e"]
    def availability datespec="today"
      config = CalendarAssistant::Config.new options: options
      ca = CalendarAssistant.new config
      events = ca.availability CLIHelpers.parse_datespec(datespec)
      CLIHelpers::Out.new.print_available_blocks ca, events, options
    end

    desc "config",
         "Dump your configuration parameters (merge of defaults and overrides from #{CalendarAssistant::Config::CONFIG_FILE_PATH})"
    def config
      config = CalendarAssistant::Config.new
      settings = {}
      setting_names = CalendarAssistant::Config::Keys::Settings.constants.map { |k| CalendarAssistant::Config::Keys::Settings.const_get k }
      setting_names.each do |key|
        settings[key] = config.setting key
      end
      puts TOML::Generator.new({CalendarAssistant::Config::Keys::SETTINGS => settings}).body
    end

    private

    def handle_help_args
      if options[:help]
        help(current_command_chain.first)
        return true
      end
    end
  end
end
