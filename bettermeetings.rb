require 'google/apis/calendar_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'

require 'fileutils'

OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
APPLICATION_NAME = 'BetterMeetingsCLI'
CLIENT_SECRETS_PATH = 'client_secret.json'
CREDENTIALS_PATH = File.join(Dir.home, '.credentials',
                             "calendar-ruby-bettermeetings.yaml")
SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY

##
# Ensure valid credentials, either by restoring from the saved credentials
# files or intitiating an OAuth2 authorization. If authorization is required,
# the user's default browser will be launched to approve the request.
#
# @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
def authorize
  FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

  client_id = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
  token_store = Google::Auth::Stores::FileTokenStore.new(file: CREDENTIALS_PATH)
  authorizer = Google::Auth::UserAuthorizer.new(
    client_id, SCOPE, token_store)
  user_id = 'default'
  credentials = authorizer.get_credentials(user_id)
  if credentials.nil?
    url = authorizer.get_authorization_url(
      base_url: OOB_URI)
    puts "Open the following URL in the browser and enter the " +
         "resulting code after authorization"
    puts url
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: OOB_URI)
  end
  credentials
end

def get_time(event_time)
  if event_time.date_time
    event_time.date_time.to_time
  else
    date_array = event_time.date.split("-")
    Time.new(*date_array)
  end
end

# in mins
def duration(event)
  start_time = get_time(event.start)
  end_time = get_time(event.end)
  (end_time - start_time) / 60
end

# Initialize the API
service = Google::Apis::CalendarV3::CalendarService.new
service.client_options.application_name = APPLICATION_NAME
service.authorization = authorize

# Fetch the next 10 events for the user
calendar_id = 'primary'
one_week_ago = Time.now - (60*60*24*7)
response = service.list_events(calendar_id,
                               max_results: 10,
                               single_events: true,
                               order_by: 'startTime',
                               time_min: one_week_ago.iso8601,
                               time_max: Time.now.iso8601)

puts "Meetings last week (starting #{one_week_ago.iso8601})"
puts "No events found" if response.items.empty?
total_meeting_min = 0
response.items.each do |event|
  duration = duration(event)
  if duration < (60*4)
    total_meeting_min += duration
    puts "- #{event.summary} (#{duration} min)"
  end
end

puts "Total meeting time for past week: #{total_meeting_min} minutes"
puts "Total meeting time for past week: #{total_meeting_min / 60.0} hours"
