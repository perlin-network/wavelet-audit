package main

import (
	"flag"
	"fmt"
	"github.com/perlin-network/noise"
	"github.com/perlin-network/noise/cipher"
	"github.com/perlin-network/noise/handshake"
	"github.com/perlin-network/noise/skademlia"
	"github.com/perlin-network/noise/xnoise"
	"io/ioutil"
	"net"
	"os"
	"strconv"
	"strings"
	"regexp"
	"time"
	"math/rand"
	"errors"
)

var nodeName string
var nodeAddress string

const (
	OpcodeChat = "examples.chat"
	C1         = 8
	C2         = 8
)

func protocol(node *noise.Node, address string) (*skademlia.Protocol, noise.Protocol) {
	ecdh := handshake.NewECDH()
	ecdh.Logger().SetOutput(os.Stdout)
	ecdh.RegisterOpcodes(node)

	aead := cipher.NewAEAD()
	aead.Logger().SetOutput(os.Stdout)
	aead.RegisterOpcodes(node)

	keys, err := skademlia.NewKeys(C1, C2)
	if err != nil {
		panic(err)
	}

	fmt.Println("Beginning S/Kademlia handshake")
	overlay := skademlia.New(net.JoinHostPort(address, strconv.Itoa(node.Addr().(*net.TCPAddr).Port)), keys, xnoise.DialTCP)
	overlay.Logger().SetOutput(os.Stdout)
	overlay.RegisterOpcodes(node)
	overlay.WithC1(C1)
	overlay.WithC2(C2)

	node.RegisterOpcode(OpcodeChat, node.NextAvailableOpcode())

	fmt.Println("Done with S/Kademlia handshake")
	chatProtocol := func(ctx noise.Context) error {
		id := ctx.Get(skademlia.KeyID).(*skademlia.ID)

		for {
			select {
			case <-ctx.Done():
				return nil
			case ctx := <-ctx.Peer().Recv(node.Opcode(OpcodeChat)):
				fmt.Printf("From ID=%s> %s\n", id.String(), ctx.Bytes())
			}
		}
	}

	return overlay, noise.NewProtocol(xnoise.LogErrors, ecdh.Protocol(), aead.Protocol(), overlay.Protocol(), chatProtocol)
}

func getLocalIP() string {
	file := "local-ip"
	contentsBytes, err    := ioutil.ReadFile(file);
	if err != nil {
		panic(err);
	}
	localIP := strings.TrimSpace(string(contentsBytes));
	return localIP
}

func shuffleArray(input []string) (output []string) {
	output = make([]string, len(input))
	copy(output, input)
	rand.Seed(time.Now().UnixNano())
	rand.Shuffle(len(output), func(i, j int) { output[i], output[j] = output[j], output[i] })
	return
}

func getPeers() []string {
	filename := "remote-ips"

	buf, err := ioutil.ReadFile(filename)
	if err != nil {
		panic(err)
	}

	contents := string(buf)
	addresses := strings.Split(contents, "\n")

	var peers []string

	for _, peerAddr := range addresses {
		if peerAddr == "" {
			continue
		}

		peer := fmt.Sprintf("[%v]:8911", peerAddr)
		peers = append(peers, peer)
	}

	return peers
}

func contains(s []*noise.Peer, e string) bool {
	for _, a := range s {
		if a.Addr().String() == e {
			return true
		}
	}
	return false
}

func main() {
	flag.Parse()

	nodeName = flag.Arg(0)
	nodeAddress = getLocalIP()

	node, err := xnoise.ListenTCP(8911)
	if err != nil {
		panic(err)
	}

	network, protocol := protocol(node, nodeAddress)
	node.FollowProtocol(protocol)

	fmt.Println("Listening for connections on port:", node.Addr().(*net.TCPAddr).Port)

	defer node.Shutdown()

	isMasterListener := false
	if matched, _ := regexp.MatchString("-0$", nodeName); matched {
		isMasterListener = true
	}

	if !isMasterListener {
		addresses := getPeers()

		go func(){
			for {
				connectedPeersCount := len(network.Peers(node))
				if connectedPeersCount >= 4 {
					fmt.Println("[main] Current connection count =", connectedPeersCount)
					time.Sleep(1 * time.Second)
					continue
				}

				for _, address := range shuffleArray(addresses) {
					if contains(network.Peers(node), address) {
						continue
					}

					fmt.Println("Connecting to:", address)

					peer, err := xnoise.DialTCP(node, address)

					if err != nil {
						fmt.Printf("Unable to connect to %s: %v\n", err)
						time.Sleep(1000 * time.Millisecond)
						continue
					}

					go func(peer *noise.Peer, address string) {
						peer.WaitFor(skademlia.SignalAuthenticated)
						fmt.Println("Connected to", address)
					}(peer, address)


					break
				}

				time.Sleep(1 * time.Second)
			}
		}()

		for {
			connectedPeersCount := len(network.Peers(node))
			if connectedPeersCount >= 1 {
				break
			}
			time.Sleep(1 * time.Second)
		}

	}

	fmt.Println("Bootstrapping...")

	peers := network.Bootstrap(node)

	var ids []string

	for _, id := range peers {
		ids = append(ids, id.String())
	}

	fmt.Println("Bootstrapped to:", strings.Join(ids, ", "))

	fmt.Println("Listener node started.")

	for {
		time.Sleep(5 * time.Second)

		for _, peer := range network.Peers(node) {
			_, err = network.Ping(peer.Ctx())
			if err != nil {
				fmt.Printf("Error pinging: %+v\n", err);
				fmt.Printf("[2] Disconnecting from %s\n", peer.Addr());
				peer.Disconnect(errors.New("Goodbye"))
			}
		}
	}
}
