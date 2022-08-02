module v_tenminutemail

import time

fn test_new_mail()? {
	mut mail := new_mail()?
	assert mail.host == '10minutemail'
	eprintln('waiting 5 seconds...')
	time.sleep(5 * time.second)
	sw := mail.seconds_left(false)?
	ep := mail.seconds_left(true)?
	assert sw == ep 
	// really depends on internet speed here, but it is fairly accurate
	// i recommend using the builtin stopwatch
}