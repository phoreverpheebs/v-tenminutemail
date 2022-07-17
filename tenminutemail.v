// tenminutemail.v
// https://10minutemail.com/
module tenminutemail

import time
import net.http
import context
import strconv
import x.json2 as json

const (
	mail_generation_endpoint = 'https://10minutemail.com/session/address'
	seconds_left_endpoint = 'https://10minutemail.com/session/secondsLeft'
	messages_endpoint = 'https://10minutemail.com/messages/messagesAfter/' // int
	message_count_endpoint = 'https://10minutemail.com/messages/messageCount'
	is_email_expired_endpoint = 'https://10minutemail.com/session/expired'
)

const err_timeout_exceeded = error('timeout exceeded')

pub fn new_mail() ?Mail {
	// initialise 10minutemail struct
	mut mail := Mail{
		host: '10minutemail'
		stopwatch: time.new_stopwatch()
	}

	// get email and session cookie from api
	resp := http.get(mail_generation_endpoint) or { 
		return error('error while sending email generation GET request: $err')
	}

	if resp.status() != .ok {
		return error('invalid status response: $resp.status_code')
	}

	for _, cookie in resp.cookies() {
		if cookie.name == 'JSESSIONID' {
			mail.session_auth = cookie.value
		}
	}

	// double check that the cookies were returned correctly
	if mail.session_auth == '' {
		return error('didn\'t get session cookie')
	}
	
	raw_response := json.raw_decode(resp.body) or {
		return error('error parsing address response body')
	}

	mail.mail = raw_response.as_map()['address']?.str()

	return mail
}

// Returns amount of new messages
pub fn (mut m Mail) check_for_messages() ?int {
	mut config := http.FetchConfig{
		url: message_count_endpoint
		method: .get
		cookies: {
			'JSESSIONID': m.session_auth
		}
	}

	message_count_resp := http.fetch(config) or {
		return error('unable to fetch message count: $err')
	}

	if message_count_resp.status() != .ok {
		return error('unexpected status on message count fetch: $message_count_resp.status_code')
	}

	raw_message_count := json.raw_decode(message_count_resp.body) or {
		return error('error parsing message count response')
	}

	message_count_difference := raw_message_count.as_map()['messageCount']?.int() - m.message_count

	if message_count_difference > 0 {
		config.url = '${messages_endpoint}${m.message_count.str()}'
		m.message_count += message_count_difference

		messages_resp := http.fetch(config) or {
			return error('unable to fetch messages: $err')
		}

		if messages_resp.status() != .ok {
			return error('unexpected status on messages fetch: $messages_resp.status_code')
		}

		raw_messages := json.raw_decode(messages_resp.body) or {
			return error('error parsing messages response')
		}

		for _, mut message in raw_messages.arr() {
			message_decoded := json.decode<Message>(message.json_str()) or {
				return error('error parsing messages')
			}
			
			m.messages << message_decoded
		}

		return message_count_difference
	} else {
		return 0
	}
}

pub fn (mut m Mail) mail() string {
	return m.mail
}

pub fn (mut m Mail) messages() []Message {
	return m.messages
}

pub fn (mut m Mail) message_at_index(idx int) Message {
	return m.messages[idx]
}

// there is an endpoint for this, but to save network
// requests we will just use the stopwatch in the mail struct
pub fn (mut m Mail) seconds_left(use_endpoint bool) ?int {
	if use_endpoint {
		config := http.FetchConfig{
			url: seconds_left_endpoint
			method: .get
			cookies: {
				'JSESSIONID': m.session_auth
			}
		}

		seconds_left_resp := http.fetch(config) or {
			return error('unable to fetch seconds left: $err')
		}

		if seconds_left_resp.status() != .ok {
			return error('unexpected status on seconds left fetch: $seconds_left_resp.status_code')
		}

		raw_seconds_left := json.raw_decode(seconds_left_resp.body) or {
			return error('error parsing seconds left response')
		}

		return strconv.atoi(raw_seconds_left.as_map()['secondsLeft']?.str()) or {
			return error('unable to parse seconds left into integer')
		}
	} else {
		return int(599 - m.stopwatch.elapsed().seconds())
	}
}

// wait for expected_message_amount of messages to be recieved by m.mail()
// the function will wait wait_time between requests
// timeout is the duration to wait before expiring
// messages are written to m.messages
pub fn (mut m Mail) wait_for_message(expected_message_amount int, timeout time.Duration, wait_time time.Duration)? {
	mut messages_recieved := 0
	mut bg := context.background()
	mut ctx, cancel := context.with_timeout(mut &bg, timeout)
	defer {
		cancel()
	}

	ctx_ch := ctx.done()
	for messages_recieved < expected_message_amount {
		select {
			_ := <-ctx_ch {
				return err_timeout_exceeded
			}
			else {
				messages_recieved += m.check_for_messages()?
			}
		}
		time.sleep(wait_time)
	}

	return
}

pub struct Mail {
mut:
	mail			string
	messages		[]Message
//
	session_auth	string
	message_count	int
pub:
	host 			string
//	
	stopwatch		time.StopWatch
}

pub struct Message {
mut:
	read					bool
	expanded 				bool
	forwarded				bool
	replied_to				bool
	sent_date				string
	sent_date_formatted		string
	sender					string
	from					string
	subject					string
	body_plain_text			string
	body_html_content		string
	body_preview			string
	id						string
}

pub fn (mut m Message) from_json(f json.Any) {
	for k, v in f.as_map() {
		match k {
			'read' { m.read = v.bool() }
			'expanded' { m.expanded = v.bool() }
			'forwarded' { m.forwarded = v.bool() }
			'repliedTo' { m.replied_to = v.bool() }
			'sentDate' { m.sent_date = v.str() }
			'sentDateFormatted' { m.sent_date_formatted = v.str() }
			'sender' { m.sender = v.str() }
			'from' { m.from = v.str() }
			'subject' { m.subject = v.str() }
			'bodyPlainText' { m.body_plain_text = v.str() }
			'bodyHtmlContent' { m.body_html_content = v.str() }
			'bodyPreview' { m.body_preview = v.str() }
			'id' { m.id = v.str() }
			else {}
		}
	}
}