#! /usr/bin/env tclsh

set nodeName [lindex $argv 0]
set port 3000

proc getPeersInClass {class} {
	set peers [list]
	foreach file [glob -nocomplain -directory .. "${class}-*"] {
		catch {
			set fd [open [file join $file local-ip]]
		}
		if {![info exists fd]} {
			continue
		}

		gets $fd peer
		lappend peers $peer

		close $fd
	}

	return $peers
}

proc otherPeerInClass {class} {
	set peers [getPeersInClass $class]
	if {[llength $peers] == 0} {
		return ""
	}

	set randomIdx [expr {entier(rand() * [llength $peers])}]

	set peer [lindex $peers $randomIdx]

	return $peer
}

proc tarpitOutbound {} {
	after 10000 tarpitOutbound

	if {[info exists ::tarpitOutboundFD]} {
		return
	}

	set peer [otherPeerInClass "good"]
	if {$peer eq ""} {
		return
	}

	puts "\[$::nodeName\] Connecting to $peer/$::port to tarpit"
	catch {
		set ::tarpitOutboundFD [socket -async [otherPeer] $::port]
		fconfigure $::tarpitOutboundFD -buffersize 1 -encoding binary -translation binary -blocking false
		slowRead $::tarpitOutboundFD $peer $::port { unset ::tarpitOutboundFD; close $sock }
	}
}

proc slowRead {sock addr port {close ""}} {
	if {[eof $sock]} {
		puts "\[$::nodeName\] EOF from $addr/$port"
		if {$close eq ""} {
			set close {close $sock}
		}
		catch $close

		return
	}

	after 5000 [list slowRead $sock $addr $port $close]

puts "[clock seconds] Reading 1 byte from $sock"
	read $sock 1
}

proc accept {sock addr port} {
	puts "\[$::nodeName\] Incoming connection from $addr/$port, will tarpit it"

	fconfigure $sock -buffersize 1 -encoding binary -translation binary -blocking false

	slowRead $sock $addr $port
}

puts "\[$::nodeName] Listening on port $::port"
socket -server accept $::port

tarpitOutbound

vwait forever
