#!/usr/bin/env bash

# Wait until web host is reachable or timer expires
host=www.somehost.example
delay=10   # retry every <delay> seconds
timer=120  # wait this many seconds before failing

echo "Checking reachability of '$host'"
while true; do
    if [[ $timer -le 0 ]]; then
        echo Host never became reachable. Timer
        echo expired before network was ready.
        echo Exiting with failure.
        exit 1
    fi
    ping -c 1 $host > /dev/null 2>&1 && break  # break loop if ping succeeds
    echo "Waiting $delay seconds before trying again. Will timeout if not reachable within $timer second."
    sleep $delay
    timer=$[$timer-$delay]
done
