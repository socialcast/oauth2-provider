require "spec_helper"

describe OAuth2::Provider::Logging do
  class LogTestHarness
    include OAuth2::Provider::Logging
  end


  subject do
    LogTestHarness.new
  end


  describe "log method" do
    let(:mock_logger) { stub(:mock_logger) }
    let(:formatted_log_message) { "FORMATTED_MESSAGE!" }
    let(:raw_message) { "RAW_MESSAGE!" }

    before do
      mock_logger.stubs(:add)
      OAuth2::Provider.stubs(:logger).returns(mock_logger)
    end


    context "without a logger" do
      before do
        subject.stubs(:current_logger).returns(nil)
      end
      it "shouldn't log" do
        subject.expects(:format_log_message).never
        subject.log raw_message
      end

      it "should return nil" do
        subject.log(raw_message).should be_nil
      end
    end

    context "with a logger" do
      before do
        subject.expects(:format_log_message).returns(formatted_log_message)
      end
      it "should log with the info level if no level is provided" do
        mock_logger.expects(:add).with(Logger::Severity::INFO, formatted_log_message)
        subject.log raw_message
      end
      it "should log with the supplied level if a level is provided" do
        mock_logger.expects(:add).with(Logger::Severity::DEBUG, formatted_log_message)
        subject.log raw_message, :level => :debug
      end
      it "should return nil" do
        subject.log(raw_message).should be_nil
      end
    end
  end

  describe "format_log_message method" do
    let(:raw_message) { "RAW_MESSAGE!" }
    let(:formatted_message) { subject.send :format_log_message, raw_message } 

    it "should prefix the message [OAUTH2-PROVIDER]" do
      formatted_message.should =~ /\[OAUTH2-PROVIDER\].*#{raw_message}/ 
    end

    it "should include the current time" do
      formatted_time = Time.now.utc.iso8601
      formatted_message.should =~ /.*#{formatted_time}.*#{raw_message}/ 
    end
  end


  describe 'current_logger method' do
    let(:mock_custom_logger) { :custom_logger }
    let(:mock_rack_logger) { :rack_logger }

    context "with a custom logger" do
      before do
        OAuth2::Provider.stubs(:logger).returns(mock_custom_logger)
      end

      it "should return the custom logger" do
        subject.send(:current_logger).should == mock_custom_logger
      end

      context "and a rack logger" do
        before do
          subject.stubs(:get_env_property).with('rack.logger').returns(mock_rack_logger)
        end

        it "should return the custom logger in preference to the rack logger" do
          subject.send(:current_logger).should == mock_custom_logger
        end
      end
    end

    context "with a rack logger" do
      before do
        subject.stubs(:get_env_property).with('rack.logger').returns(mock_rack_logger)
      end

      it "should return the custom logger in preference to the rack logger" do
        subject.send(:current_logger).should == mock_rack_logger
      end
    end

  end
end
