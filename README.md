<h1>v-10minutemail</h1>

* V wrapper for 10minutemail.com
* Get a temporary email
* Recieve emails

<h2>Installation</h2>

`v install https://github.com/phoreverpheebs/v-10minutemail`

<h2>Usage</h2>

Initialise a new email:
```v
mymail := 10minutemail.new_mail() or { panic(err) }

// print current email
println(mymail.mail())
```

Check for a message and dump it:
```v
messages_recieved := mymail.check_for_messages() or { panic(err) }
if messages_recieved > 0 {
    dump(mymail.message_at_index(0))
    // or mymail.messages()[0]
}
```

Or use the implemented function to wait for a message:
```v
expected_messages := 1
timeout := 2 * time.minute
wait_time := 5 * time.second
mymail.wait_for_message(expected_messages, timeout, wait_time) or { panic(err) }
// upon return of the function the message(s) are written to the latest indices
dump(mymail.messages()[mymail.messages().len-expected_messages..])
```

Check remaining seconds of mail:
```v
remaining := mymail.seconds_left(false)? // doesn't use endpoint (will not return an error)
dump(remaining)

endpoint_remaining := mymail.seconds_left(true) or { panic(err) } // uses endpoint
dump(endpoint_remaining)
```
