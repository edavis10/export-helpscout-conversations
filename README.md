# export-helpscout-conversations

Ruby script to export conversations/threads from HelpScout to JSON using HelpScout API v2

## Installation

1. Install the rest-client gem

```
gem install rest-client
```

2. Create an App in HelpScout to access the API: Log into HelpScout, go to Your Profile, click on My Apps, and click on Create My App. You can enter any url for the Redirection URL, as it will not be used. Copy the App ID and App Secret for the new app.

3. Use the HelpScout API client credentials flow to get an API access_token good for 48 hours

```
curl -X POST https://api.helpscout.net/v2/oauth2/token --data "grant_type=client_credentials" --data "client_id=<your-app-ID>" --data "client_secret=<your-app-secret>"
```

## Usage

To export all of your HelpScout mailboxes, run the script as follows:

```
HELPSCOUT_API_TOKEN=<your-access-token> ruby export-helpscout-conversations
```

The output of the script will be a sequence of JSON objects, one per line. There are two kinds of JSON objects: a response to the "List Conversations" API call containing a (likely paginated) list of conversations, and a response to the "List Threads" API call containing a (possibly paginated) list of threads for a single conversation. Note that the script adds a "conversation" attribute to each "threads" API object containing the conversation id to make it easier to link the list of threads to the conversation they are from. For additional information about the output format, see the HelpScout API documentation for the List Conversations endpoint at https://developer.helpscout.com/mailbox-api/endpoints/conversations/list/ and the List Threads endpoint at https://developer.helpscout.com/mailbox-api/endpoints/conversations/threads/list/

If you want to get the conversations and threads from a specific mailbox, use:

```
HELPSCOUT_MAILBOXES=<your-mailbox-slug-or-id> HELPSCOUT_API_TOKEN=<your-access-token> ruby export-helpscout-conversations
```

You can find the mailbox slug in HelpScout by clicking on the Mailbox tab, and copying it from the URL, e.g. https://secure.helpscout.net/mailbox/your-mailbox-slug/

Note that the HelpScout API rate-limits requests for standard accounts to 200 requests per minute. The script enforces a 150 request-per-minute limit to stay below this. You can adjust the rate limiting by setting HELPSCOUT_API_RATE_LIMIT (defaults to 150) and HELPSCOUT_API_RATE_SECONDS (defaults to 60) to adjust this rate limit.
