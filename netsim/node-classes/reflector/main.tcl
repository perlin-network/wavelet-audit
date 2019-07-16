#! /usr/bin/env tclsh

set nodeName [lindex $argv 0]
set port 3000 

proc localIP {} {
	if {[info exists ::localIP]} {
		return $::localIP
	}

	set fd [open local-ip]
	gets $fd localIP
	close $fd

	set ::localIP $localIP

	return $::localIP
}

proc getClassAndIndex {ip} {
	set work [split $ip :]
	set classAndIndex [lindex $work 3]
	if {$classAndIndex eq ""} {
		set classAndIndex 0
	}

	set classAndIndex 0x${classAndIndex}

	set class [expr {($classAndIndex >> 12) & 0xf}]
	set index [expr {$classAndIndex & 0xfff}]

	return [dict create class $class index $index]
}

proc ipIsSameClass {ip} {
	set localIP [localIP]
	set localClass [dict get [getClassAndIndex $localIP] class]
	set ipClass    [dict get [getClassAndIndex $ip]      class]

	if {$ipClass == $localClass} {
		return true
	}

	return false
}

proc getPeers {} {
	set fd [open remote-ips]
	set data [read $fd]
	close $fd

	set peerAddrs [split $data "\n"]
	set otherPeers [list]
	foreach peerAddr $peerAddrs {
		if {$peerAddr eq ""} {
			continue
		}

		if {[ipIsSameClass $peerAddr]} {
			continue
		}

		lappend otherPeers $peerAddr
	}

	return $otherPeers
}

proc otherPeer {} {
	if {[info exists ::otherPeer]} {
		return $::otherPeer
	}

	set peers [getPeers]
	set randomIdx [expr {entier(rand() * [llength $peers])}]

	set peer [lindex $peers $randomIdx]

	set ::otherPeer $peer

	return $::otherPeer
}

proc finalize {sock addr port otherSock otherAddr otherPort args} {
	puts "\[$::nodeName\] EOF from $sock/$addr/port (other side is $otherSock/$otherAddr/$otherPort)"
	flush stdout

	catch {
		close $sock
	}
	catch {
		close $otherSock
	}
}

proc accept {sock addr port} {
	catch {
		set otherPeer [otherPeer]
	}
	if {![info exists otherPeer]} {
		close $sock
		return
	}

	puts "\[$::nodeName\] Connecting to $otherPeer/$::port for $sock/$addr/$port"
	flush stdout

	catch {
		set otherSock [socket $otherPeer $::port]
	} otherConnErr

	if {![info exists otherSock]} {
		puts "\[$::nodeName\] Connecting to $otherPeer/$::port failed: $otherConnErr"
		close $sock
		return
	}

	fconfigure $sock -blocking true -translation binary -encoding binary
	fconfigure $otherSock -blocking true -translation binary -encoding binary

	fcopy $sock $otherSock -command [list finalize $sock $addr $port $otherSock $otherPeer $::port]
	fcopy $otherSock $sock -command [list finalize $otherSock $otherPeer $::port $sock $addr $port]
}

puts "\[$::nodeName] Listening on port $::port"
socket -server accept $::port

vwait forever
