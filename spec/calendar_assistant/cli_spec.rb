describe CalendarAssistant::CLI do
  describe CalendarAssistant::Helpers do
    it "test time_or_time_range"
    it "test print_events"
  end

  describe "commands" do
    around do |example|
      # freeze time so we can mock with Chronic strings
      Timecop.freeze(Time.local(2018, 7, 13, 12, 1, 1)) do
        example.run
      end
    end
    
    let(:profile_name) { "work" }
    let(:ca) { instance_double("CalendarAssistant") }
    let(:events) { [instance_double("Event")] }

    before do
      expect(CalendarAssistant).to receive(:new).with(profile_name).and_return(ca)
    end
          
    describe "show" do
      context "with no datespec" do
        it "calls find_events for today" do
          expect(ca).to receive(:find_events).
                          with(Chronic.parse("today")).
                          and_return(events)
          expect(CalendarAssistant::Helpers).to receive(:print_events).with(ca, events, anything)

          CalendarAssistant::CLI.start ["show", profile_name]
        end
      end

      context "with a date" do
        it "calls find_events with the right range" do
          expect(ca).to receive(:find_events).
                          with(Chronic.parse("tomorrow")).
                          and_return(events)
          expect(CalendarAssistant::Helpers).to receive(:print_events).with(ca, events, anything)

          CalendarAssistant::CLI.start ["show", profile_name, "tomorrow"]
        end
      end

      context "with a date range" do
        it "calls find_events with the right range" do
          expect(ca).to receive(:find_events).
                          with(Chronic.parse("tomorrow")..Chronic.parse("two days from now")).
                          and_return(events)
          expect(CalendarAssistant::Helpers).to receive(:print_events).with(ca, events, anything)

          CalendarAssistant::CLI.start ["show", profile_name, "tomorrow...two days from now"]
        end
      end
    end

    describe "location" do
      describe "show" do
        context "with no datespec" do
          it "calls find_location_events for today" do
            expect(ca).to receive(:find_location_events).
                            with(Chronic.parse("today")).
                            and_return(events)
            expect(CalendarAssistant::Helpers).to receive(:print_events).with(ca, events, anything)

            CalendarAssistant::CLI.start ["location", "show", profile_name]
          end
        end

        context "with a date" do
          it "calls find_location_events with the right range" do
            expect(ca).to receive(:find_location_events).
                            with(Chronic.parse("tomorrow")).
                            and_return(events)
            expect(CalendarAssistant::Helpers).to receive(:print_events).with(ca, events, anything)

            CalendarAssistant::CLI.start ["location", "show", profile_name, "tomorrow"]
          end
        end

        context "with a date range" do
          it "calls find_location_events with the right range" do
            expect(ca).to receive(:find_location_events).
                            with(Chronic.parse("tomorrow")..Chronic.parse("two days from now")).
                            and_return(events)
            expect(CalendarAssistant::Helpers).to receive(:print_events).with(ca, events, anything)

            CalendarAssistant::CLI.start ["location", "show", profile_name, "tomorrow...two days from now"]
          end
        end
      end

      xdescribe "set" do
        context "for a date" do
          it "calls create_location_event with the right arguments" do
            expect(mock_ca).to receive("create_location_event").
                                 with(Chronic.parse("tomorrow"), "Palo Alto").
                                 and_return({})

            CalendarAssistant::CLI.start ["location", "set", calendar_id, "tomorrow", "Palo Alto"]
          end
        end

        context "for a date range with spaces" do
          it "calls create_location_event with the right arguments" do
            expect(mock_ca).to receive("create_location_event").
                                 with(Chronic.parse("tomorrow")..(Chronic.parse("three days from now") + 1.day).beginning_of_day,
                                      "Palo Alto").
                                 and_return({})

            CalendarAssistant::CLI.start ["location", "set", calendar_id, "tomorrow ... three days from now", "Palo Alto"]
          end
        end

        context "for a date range without spaces" do
          it "calls create_location_event with the right arguments" do
            expect(mock_ca).to receive("create_location_event").
                                 with(Chronic.parse("tomorrow")..(Chronic.parse("three days from now") + 1.day).beginning_of_day,
                                      "Palo Alto").
                                 and_return({})

            CalendarAssistant::CLI.start ["location", "set", calendar_id, "tomorrow...three days from now", "Palo Alto"]
          end
        end
      end
    end
  end
end
