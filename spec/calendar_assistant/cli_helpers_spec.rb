describe CalendarAssistant::CLIHelpers do
  describe ".parse_datespec" do
    describe "parsing" do
      context "passed a range with two dots" do
        it "parses properly" do
          expect(subject.parse_datespec("today..tomorrow")).to be_a(Range)
        end
      end

      context "passed a range with three dots" do
        it "parses properly" do
          expect(subject.parse_datespec("today...tomorrow")).to be_a(Range)
        end
      end

      context "passed a range with dots and spaces" do
        it "parses properly" do
          expect(subject.parse_datespec("today .. tomorrow")).to be_a(Range)
          expect(subject.parse_datespec("today.. tomorrow")).to be_a(Range)
          expect(subject.parse_datespec("today ..tomorrow")).to be_a(Range)
          expect(subject.parse_datespec("today ... tomorrow")).to be_a(Range)
          expect(subject.parse_datespec("today... tomorrow")).to be_a(Range)
          expect(subject.parse_datespec("today ...tomorrow")).to be_a(Range)
        end
      end
    end

    describe "returned range" do
      around do |example|
        # freeze time so we can mock with Chronic strings
        Timecop.freeze(Time.local(2018, 7, 13, 12, 1, 1)) do
          example.run
        end
      end

      context "passed a single date or time" do
        it "returns a range for all of the date" do
          expect(subject.parse_datespec("today")).to eq(Time.now.beginning_of_day..Time.now.end_of_day)
        end
      end

      context "passed a date range" do
        it "returns a range for all of the days in the date range" do
          expect(subject.parse_datespec("today..tomorrow")).to eq(Time.now.beginning_of_day..(Time.now+1.day).end_of_day)
        end
      end

      context "passed a time range within a single day" do
        it "returns the time range" do
          expect(subject.parse_datespec("five minutes ago .. five minutes from now")).
            to eq(Chronic.parse("five minutes ago")..Chronic.parse("five minutes from now"))
        end
      end
    end
  end

  describe ".now" do
    it { }
  end

  describe ".find_av_uri" do
    let(:ca) { instance_double("CalendarAssistant") }

    describe "search range" do
      around do |example|
        # freeze time so we can mock with Chronic strings
        Timecop.freeze(Time.local(2018, 7, 13, 12, 1, 1)) do
          example.run
        end
      end

      it "searches in a narrow range around the specified time" do
        range = Time.now..(Time.now+1.minute)
        expect(ca).to receive(:find_events).with(range).and_return([])

        subject.find_av_uri(ca, "now")
      end
    end

    describe "meeting preference" do
      let(:accepted_event) { instance_double("accepted event", av_uri: "accepted", response_status: GCal::Event::RESPONSE_ACCEPTED) }
      let(:accepted2_event) { instance_double("accepted2 event", av_uri: "accepted2", response_status: GCal::Event::RESPONSE_ACCEPTED) }
      let(:tentative_event) { instance_double("tentative event", av_uri: "tentative", response_status: GCal::Event::RESPONSE_TENTATIVE) }
      let(:needs_action_event) { instance_double("needs_action event", av_uri: "needs_action", response_status: GCal::Event::RESPONSE_NEEDS_ACTION) }
      let(:declined_event) { instance_double("declined event", av_uri: "declined", response_status: GCal::Event::RESPONSE_DECLINED) }

      it "prefers later meetings to earlier meetings" do
        # reminder that #find_events returns in order of start time
        allow(ca).to receive(:find_events).and_return([accepted_event, accepted2_event])

        expect(subject.find_av_uri(ca, "now")).to eq("accepted2")
      end

      it "prefers accepted meetings to all other responses" do
        allow(ca).to receive(:find_events).and_return([accepted_event, tentative_event, needs_action_event, declined_event])

        expect(subject.find_av_uri(ca, "now")).to eq("accepted")
      end

      it "prefers tentative meetings to needsAction and declined" do
        allow(ca).to receive(:find_events).and_return([tentative_event, needs_action_event, declined_event])

        expect(subject.find_av_uri(ca, "now")).to eq("tentative")
      end

      it "prefers needsAction meetings to declined" do
        allow(ca).to receive(:find_events).and_return([needs_action_event, declined_event])

        expect(subject.find_av_uri(ca, "now")).to eq("needs_action")
      end

      it "never chooses declined meetings" do
        allow(ca).to receive(:find_events).and_return([declined_event])

        expect(subject.find_av_uri(ca, "now")).to eq(nil)
      end
    end
  end

  describe CalendarAssistant::CLIHelpers::Out do
    it "test print_now!"
    it "test print_events"
    it "test puts"
    it "test launch"
  end
end
