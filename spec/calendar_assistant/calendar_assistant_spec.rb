describe CalendarAssistant do
  describe "class methods" do
    describe ".date_range_cast" do
      context "given a Range of Times" do
        let(:start_time) { Chronic.parse "72 hours ago" }
        let(:end_time) { Chronic.parse "30 hours from now" }

        it "returns a Date range with the end date augmented for an all-day-event" do
          result = CalendarAssistant.date_range_cast(start_time..end_time)
          expect(result).to eq(start_time.to_date..(end_time.to_date + 1))
        end
      end
    end

    describe ".in_tz" do
      it "sets the timezone and restores it" do
        Time.zone = "Pacific/Fiji"
        ENV["TZ"] = "Pacific/Fiji"
        CalendarAssistant.in_tz "Europe/Istanbul" do
          expect(Time.zone.name).to eq("Europe/Istanbul")
          expect(ENV["TZ"]).to eq("Europe/Istanbul")
        end
        expect(Time.zone.name).to eq("Pacific/Fiji")
        expect(ENV["TZ"]).to eq("Pacific/Fiji")
      end

      it "exceptionally restores the timezone" do
        Time.zone = "Pacific/Fiji"
        ENV["TZ"] = "Pacific/Fiji"
        begin
          CalendarAssistant.in_tz "Europe/Istanbul" do
            raise RuntimeError
          end
        rescue
        end
        expect(Time.zone.name).to eq("Pacific/Fiji")
        expect(ENV["TZ"]).to eq("Pacific/Fiji")
      end
    end
  end

  describe "events" do
    let(:service) { instance_double("CalendarService") }
    let(:calendar) { instance_double("Calendar") }
    let(:config) { CalendarAssistant::Config.new options: config_options }
    let(:config_options) { Hash.new }
    let(:event_repository) { instance_double("EventRepository") }
    let(:event_repository_factory) { instance_double("EventRepositoryFactory") }
    let(:ca) { CalendarAssistant.new config, service: service, event_repository_factory: event_repository_factory }
    let(:event_array) { [instance_double("Event"), instance_double("Event")] }
    let(:events) { instance_double("Events", :items => event_array) }
    let(:event_set) { CalendarAssistant::EventSet.new(event_repository, []) }

    before do
      allow(event_repository).to receive(:find).and_return(event_set)
      allow(service).to receive(:get_calendar).and_return(calendar)
      allow(event_repository_factory).to receive(:new_event_repository).and_return(event_repository)
      allow(calendar).to receive(:time_zone).and_return("Europe/London")
    end

    describe "#find_events" do
      let(:time) { Time.now.beginning_of_day..(Time.now + 1.day).end_of_day }

      it "calls through to the repository" do
        expect(event_repository).to receive(:find).with(time, predicates: {})
        ca.find_events(time)
      end
    end

    describe "#lint_events" do
      let(:time) { Time.now.beginning_of_day..(Time.now + 1.day).end_of_day }
      let(:lint_event_repository) { instance_double("LintEventRepository") }

      it "calls through to the repository" do
        expect(event_repository_factory).to receive(:new_event_repository).with(service, anything, hash_including(type: :lint)).and_return(lint_event_repository)
        expect(lint_event_repository).to receive(:find).with(time, predicates: {})
        ca.lint_events(time)
      end
    end

    describe "#find_location_events" do
      let(:time) { Time.now.beginning_of_day..(Time.now + 1.day).end_of_day }
      let(:event_repository) { instance_double("EventRepository") }

      it "calls LocationEventRepository#find" do
        expect(event_repository_factory).to receive(:new_event_repository).with(service, anything, hash_including(type: :location)).and_return(event_repository)
        expect(event_repository).to receive(:find).with(time, predicates: {}).and_return(event_set)
        ca.find_location_events time
      end
    end

    describe "#create_location_event" do
      let(:time) { Time.now.beginning_of_day..(Time.now + 1.day).end_of_day }
      let(:event_repository) { instance_double("EventRepository") }

      it "calls LocationEventRepository#create" do
        expect(CalendarAssistant::LocationConfigValidator).to receive(:valid?).and_return(true)
        expect(event_repository_factory).to receive(:new_event_repository).with(service, anything, hash_including(type: :location)).and_return(event_repository)
        expect(event_repository).to receive(:create).with(time, "Hogwarts", predicates: {}).and_return(event_set)
        ca.create_location_events time, "Hogwarts"
      end
    end

    describe "#availability" do
      let(:scheduler) { instance_double(CalendarAssistant::Scheduler) }
      let(:time_range) { instance_double("time range") }

      context "looking at own calendar" do
        before do
          expect(event_repository_factory).to receive(:new_event_repository).
                                                with(anything, CalendarAssistant::Config::DEFAULT_CALENDAR_ID, anything).
                                                and_return(event_repository)
        end

        it "creates a scheduler and invokes #available_blocks" do
          expect(CalendarAssistant::Scheduler).to receive(:new).
                                                    with(ca, [event_repository]).
                                                    and_return(scheduler)
          expect(scheduler).to receive(:available_blocks).with(time_range, predicates: {}).and_return(event_set)

          response = ca.availability(time_range)

          expect(response).to eq(event_set)
        end
      end

      context "looking at someone else's calendar" do
        let(:other_calendar_id) { "somebodyelse@example.com" }
        let(:config_options) do
          {
            CalendarAssistant::Config::Keys::Options::CALENDARS => other_calendar_id,
          }
        end

        before do
          expect(event_repository_factory).to receive(:new_event_repository).
                                                with(anything, other_calendar_id, anything).
                                                and_return(event_repository)
        end

        it "creates a scheduler and invokes #available_blocks" do
          expect(CalendarAssistant::Scheduler).to receive(:new).
                                                    with(ca, [event_repository]).
                                                    and_return(scheduler)
          expect(scheduler).to receive(:available_blocks).with(time_range, predicates: {}).and_return(event_set)

          response = ca.availability(time_range)

          expect(response).to eq(event_set)
        end
      end

      context "looking at multiple calendars" do
        let(:event_repository2) { instance_double("EventRepository") }

        let(:config_options) do
          {
            CalendarAssistant::Config::Keys::Options::CALENDARS => "someone@example.com,somebodyelse@example.com",
          }
        end

        before do
          expect(event_repository_factory).to receive(:new_event_repository).
                                                with(anything, "someone@example.com", anything).
                                                and_return(event_repository)
          expect(event_repository_factory).to receive(:new_event_repository).
                                                with(anything, "somebodyelse@example.com", anything).
                                                and_return(event_repository2)
        end

        it "creates a scheduler with multiple EventRepositories" do
          expect(CalendarAssistant::Scheduler).to receive(:new).
                                                    with(ca, [event_repository, event_repository2]).
                                                    and_return(scheduler)
          expect(scheduler).to receive(:available_blocks).with(time_range, predicates: {}).and_return(event_set)

          response = ca.availability(time_range)

          expect(response).to eq(event_set)
        end
      end
    end

    describe "#in_env" do
      let(:subject) { CalendarAssistant.new config }
      let(:config) { CalendarAssistant::Config.new }

      it "calls Config#in_env" do
        expect(config).to receive(:in_env)
        ca.in_env do
        end
      end

      it "calls in_tz with the calendar timezone" do
        expect(ca).to receive(:in_tz)
        ca.in_env do
        end
      end
    end

    describe "#in_tz" do
      before do
        expect(calendar).to receive(:time_zone).and_return("a time zone id")
      end

      it "calls .in_tz with the default calendar's time zone" do
        expect(CalendarAssistant).to receive(:in_tz).with("a time zone id")
        ca.in_tz do
        end
      end
    end

    describe "#event_repository" do
      context "with no type" do
        it "invokes the factory method to create a new repository" do
          expect(event_repository_factory).to receive(:new_event_repository).with(service, "foo", anything)
          ca.event_repository("foo")
        end

        it "caches the result" do
          expect(event_repository_factory).to receive(:new_event_repository).once
          ca.event_repository("foo")
          ca.event_repository("foo")
        end
      end

      context "with a type set" do
        it "still caches the result" do
          expect(event_repository_factory).to receive(:new_event_repository).with(service, "foo", hash_including(type: :lint)).once
          expect(event_repository_factory).to receive(:new_event_repository).with(service, "foo", hash_including(type: :location)).once
          ca.event_repository("foo", type: :lint)
          ca.event_repository("foo", type: :lint)
          ca.event_repository("foo", type: :location)
          ca.event_repository("foo", type: :location)
        end
      end
    end
  end
end
